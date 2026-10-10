import 'package:flutter/material.dart';

import '../data/game_assets.dart';
import '../data/save_store.dart';
import '../engine/game.dart';
import '../engine/rules.dart';
import '../game/game_controller.dart';
import '../map/map_camera.dart';
import '../map/map_painters.dart';
import '../map/map_scene.dart';
import '../map/map_view.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'sheets.dart';
import 'widgets.dart';

void _play(BuildContext context, GameController controller) {
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)), (_) => false);
}

/// Title screen, over the map as it stands in August 1914.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.assets, required this.saves});

  final GameAssets assets;
  final SaveStore saves;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  late final MapScene _scene = MapScene(widget.assets.geometry, widget.assets.world)..setOwners(widget.assets.world.startOwners);
  late final MapCamera _camera = MapCamera(widget.assets.geometry.size);
  SaveInfo? _autosave;
  String? _error;

  @override
  void initState() {
    super.initState();
    _findAutosave();
  }

  @override
  void dispose() {
    _scene.dispose();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _findAutosave() async {
    final saves = await widget.saves.list();
    if (!mounted) return;
    setState(() => _autosave = saves.where((s) => s.isAutosave).firstOrNull);
  }

  Future<void> _continue() async {
    try {
      final loaded = await widget.saves.load(SaveStore.autosaveId, widget.assets.world);
      if (mounted) _open(loaded);
    } on FormatException catch (e) {
      setState(() {
        _autosave = null;
        _error = 'The last game cannot be continued: ${e.message}.';
      });
    }
  }

  void _open(LoadedSave loaded) {
    _play(context, GameController(assets: widget.assets, saves: widget.saves, game: loaded.game, orders: loaded.orders));
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.assets.geometry.size;
    final autosave = _autosave;
    final nations = widget.assets.world.nations;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: MapView(scene: _scene, camera: _camera, interactive: false, initialFocus: Offset(map.width * 0.42, map.height * 0.6), initialZoom: 1.5),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE6142924), Color(0x99142924), Color(0xF2142924)],
                stops: [0, 0.42, 0.78],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('ATLAS', style: TextStyle(fontFamily: AtlasFonts.display, fontSize: 64, letterSpacing: 14, height: 1, color: AtlasColors.ivory)),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Text('of Crowns', style: TextStyle(fontFamily: AtlasFonts.display, fontStyle: FontStyle.italic, fontSize: 34, height: 1.1, color: AtlasColors.brassBright)),
              ),
              Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(top: 18, bottom: 12, left: 4), height: 1.5, width: 132, color: AtlasColors.brass)),
              Text('EUROPE, AUGUST 1914', style: AtlasText.label.copyWith(fontSize: 14, color: AtlasColors.ivory)),
              const Spacer(),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: AtlasText.body.copyWith(color: const Color(0xFFF08A75)))),
              if (autosave != null) ...[
                FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 60)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('CONTINUE'),
                    Text(
                      '${autosave.nation >= 0 ? nations[autosave.nation].shortName : 'Watching'}, ${autosave.date}',
                      style: const TextStyle(fontFamily: AtlasFonts.display, fontStyle: FontStyle.italic, fontSize: 14, letterSpacing: 0, fontWeight: FontWeight.w400),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              if (autosave == null)
                FilledButton(onPressed: _newGame, style: FilledButton.styleFrom(minimumSize: const Size(64, 56)), child: const Text('NEW GAME'))
              else
                OutlinedButton(onPressed: _newGame, child: const Text('NEW GAME')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final loaded = await showLoadSheet(context, widget.assets, widget.saves);
                  if (loaded != null && mounted) {
                    _open(loaded);
                  } else {
                    _findAutosave();
                  }
                },
                child: const Text('LOAD GAME'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => showHowToPlay(context), child: const Text('HOW TO PLAY')),
            ]),
          ),
        ),
      ]),
    );
  }

  void _newGame() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NationSelect(assets: widget.assets, saves: widget.saves)));
  }
}

/// Pick a nation by tapping it on the map.
class NationSelect extends StatefulWidget {
  const NationSelect({super.key, required this.assets, required this.saves});

  final GameAssets assets;
  final SaveStore saves;

  @override
  State<NationSelect> createState() => _NationSelectState();
}

class _NationSelectState extends State<NationSelect> {
  static const _lengths = [('Short', 0.3), ('Standard', Rules.defaultWinFraction), ('Long', 0.55)];

  late final MapScene _scene = MapScene(widget.assets.geometry, widget.assets.world)..setOwners(widget.assets.world.startOwners);
  late final MapCamera _camera = MapCamera(widget.assets.geometry.size);
  final MapOverlay _overlay = MapOverlay();

  /// The opening position, to read each nation's strength from.
  late final Game _opening = Game.start(widget.assets.world, human: -1, seed: 0);
  int _nation = 0;
  double _winFraction = Rules.defaultWinFraction;

  @override
  void initState() {
    super.initState();
    _overlay.capitals = {for (final n in widget.assets.world.nations) n.capital};
    _pick(_nation, center: false);
  }

  @override
  void dispose() {
    _scene.dispose();
    _camera.dispose();
    _overlay.dispose();
    super.dispose();
  }

  void _pick(int nation, {bool center = true}) {
    final capital = widget.assets.world.nations[nation].capital;
    setState(() => _nation = nation);
    _overlay
      ..selected = capital
      ..changed();
    if (center && _camera.isLaidOut) _camera.reveal(widget.assets.geometry.provinces[capital].label, margin: 90);
  }

  void _begin() {
    final game = Game.start(widget.assets.world, human: _nation, seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF, winFraction: _winFraction);
    final controller = GameController(assets: widget.assets, saves: widget.saves, game: game)..autosave();
    _play(context, controller);
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.assets.world;
    final nation = world.nations[_nation];
    final enemies = [
      for (final other in world.nations)
        if (_opening.atWar(_nation, other.id)) other.shortName,
    ];
    final provinces = world.provinces.length;
    return Scaffold(
      backgroundColor: AtlasColors.sea,
      body: Column(children: [
        Panel(
          padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 16, 8),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), tooltip: 'Back'),
            const Expanded(child: Text('Choose your crown', style: AtlasText.title)),
          ]),
        ),
        Expanded(
          child: MapView(
            scene: _scene,
            camera: _camera,
            overlay: _overlay,
            initialFocus: widget.assets.geometry.provinces[nation.capital].label,
            initialZoom: 1.7,
            onTapProvince: (p) {
              if (p >= 0) _pick(world.startOwners[p]);
            },
          ),
        ),
        Panel(
          ruleOnTop: true,
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.paddingOf(context).bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              NationSwatch(Color(nation.color), height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nation.name, style: AtlasText.place, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    enemies.isEmpty ? 'At peace with everyone' : 'At war with ${enemies.join(', ')}',
                    style: AtlasText.note.copyWith(color: enemies.isEmpty ? AtlasColors.ivoryDim : const Color(0xFFF08A75)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Expanded(child: Stat('Provinces', '${_opening.provinceCount(_nation)}')),
                Expanded(child: Stat('Income', '${_opening.incomeOf(_nation)}')),
                Expanded(child: Stat('Army', '${_opening.unitsOf(_nation)}')),
                Expanded(child: Stat('Gold', '${_opening.state.gold[_nation]}')),
              ]),
            ),
            Text('PROVINCES NEEDED TO WIN', style: AtlasText.label),
            const SizedBox(height: 6),
            Row(children: [
              for (final (label, fraction) in _lengths)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _winFraction = fraction),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _winFraction == fraction ? AtlasColors.baizeLight : null,
                        foregroundColor: _winFraction == fraction ? AtlasColors.ivory : AtlasColors.ivoryDim,
                        side: BorderSide(color: _winFraction == fraction ? AtlasColors.brassBright : AtlasColors.baizeLight, width: _winFraction == fraction ? 1.5 : 1),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(48, 52),
                      ),
                      child: Text('${label.toUpperCase()}\n${(fraction * provinces).ceil()}', textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            FilledButton(onPressed: _begin, style: FilledButton.styleFrom(minimumSize: const Size(64, 56)), child: Text('PLAY AS ${nation.shortName.toUpperCase()}')),
          ]),
        ),
      ]),
    );
  }
}
