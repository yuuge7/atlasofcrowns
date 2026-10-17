import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../engine/game.dart';
import '../engine/orders.dart';
import 'game_assets.dart';

/// What the load screen shows about a save without opening the game in it.
class SaveInfo {
  SaveInfo({required this.id, required this.scenario, required this.nation, required this.turn, required this.date, required this.savedAt});

  /// File name without extension. [SaveStore.autosaveId] for the autosave.
  final String id;

  /// Id of the scenario the game is played in.
  final String scenario;

  /// Index of the player's nation.
  final int nation;
  final int turn;

  /// In-game date, e.g. "Mar 1915".
  final String date;
  final DateTime savedAt;

  bool get isAutosave => id == SaveStore.autosaveId;
}

class LoadedSave {
  LoadedSave(this.game, this.orders, [this.marches = const []]);

  final Game game;

  /// Orders the player had queued when saving.
  final Orders orders;

  /// Marches under way, as [GameController.marchesToJson] wrote them.
  final List<List<int>> marches;
}

/// Save files: one JSON document per game in the app's documents folder.
class SaveStore {
  /// [directory] overrides where saves go; tests pass a temporary folder.
  SaveStore({Directory? directory}) : _directory = directory; // ignore: prefer_initializing_formals

  static const autosaveId = 'autosave';
  static const maxManualSaves = 12;

  Directory? _directory;
  Future<void> _pending = Future.value();

  Future<Directory> _dir() async {
    final dir = _directory ??= Directory('${(await getApplicationDocumentsDirectory()).path}/saves');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  File _file(Directory dir, String id) => File('${dir.path}/$id.json');

  /// Writes the autosave. Writes are queued, so a slow disk never lets an
  /// older turn overwrite a newer one.
  Future<void> autosave(Game game, Orders orders, {List<List<int>> marches = const []}) => write(autosaveId, game, orders, marches: marches);

  /// Saves under a new name and returns its id. The oldest manual save goes
  /// when there are more than [maxManualSaves].
  Future<String> saveNew(Game game, Orders orders, {List<List<int>> marches = const []}) async {
    final id = 'save_${DateTime.now().millisecondsSinceEpoch}';
    await write(id, game, orders, marches: marches);
    final manual = (await list()).where((s) => !s.isAutosave).toList();
    for (final old in manual.skip(maxManualSaves)) {
      await delete(old.id);
    }
    return id;
  }

  Future<void> write(String id, Game game, Orders orders, {List<List<int>> marches = const []}) {
    final text = jsonEncode({
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'nation': game.state.human,
      'turn': game.state.turn,
      'date': game.dateLabel(game.state.turn),
      'game': game.toJson(),
      'orders': orders.toJson(),
      'marches': marches,
    });
    return _pending = _pending.catchError((_) {}).then((_) async {
      final dir = await _dir();
      // Write beside the target and rename, so a crash mid-write cannot
      // leave half a file where the last good save was.
      final temp = File('${dir.path}/$id.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(_file(dir, id).path);
    });
  }

  /// Newest first. Files that cannot be read are skipped.
  Future<List<SaveInfo>> list() async {
    await _pending.catchError((_) {});
    final dir = await _dir();
    final saves = <SaveInfo>[];
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        saves.add(SaveInfo(
          id: file.uri.pathSegments.last.replaceAll('.json', ''),
          // Saves from before there was a choice are all 1914.
          scenario: (json['game'] as Map<String, dynamic>)['scenario'] as String? ?? '1914',
          nation: json['nation'] as int,
          turn: json['turn'] as int,
          date: json['date'] as String,
          savedAt: DateTime.parse(json['savedAt'] as String),
        ));
      } on Object {
        continue;
      }
    }
    saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return saves;
  }

  /// Opens a save in whichever of the [assets] scenarios it was made in.
  /// Throws [FormatException] when the file is damaged or was made for
  /// another version of the map.
  Future<LoadedSave> load(String id, GameAssets assets) async {
    await _pending.catchError((_) {});
    final file = _file(await _dir(), id);
    final Object? json;
    try {
      json = jsonDecode(await file.readAsString());
    } on FileSystemException {
      throw const FormatException('The save file is missing');
    }
    if (json is! Map<String, dynamic>) throw const FormatException('The save file is damaged');
    try {
      final game = json['game'] as Map<String, dynamic>;
      return LoadedSave(
        Game.fromJson(assets.scenario(game['scenario'] as String), game),
        Orders.fromJson(json['orders'] as Map<String, dynamic>),
        // Saves from before marches have none.
        [for (final m in json['marches'] as List? ?? const []) (m as List).cast<int>()],
      );
    } on TypeError {
      throw const FormatException('The save file is damaged');
    }
  }

  Future<void> delete(String id) async {
    await _pending.catchError((_) {});
    final file = _file(await _dir(), id);
    if (file.existsSync()) file.deleteSync();
  }
}
