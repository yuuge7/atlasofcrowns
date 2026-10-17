import 'package:flutter/material.dart';

import '../data/game_assets.dart';
import '../data/save_store.dart';
import '../engine/game.dart';
import '../engine/rules.dart';
import '../engine/world.dart';
import '../game/game_controller.dart';
import '../map/map_camera.dart';
import '../map/map_painters.dart';
import '../map/map_scene.dart';
import '../map/map_view.dart';
import '../theme.dart';
import 'flags.dart';
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
      final loaded = await widget.saves.load(SaveStore.autosaveId, widget.assets);
      if (mounted) _open(loaded);
    } on FormatException catch (e) {
      setState(() {
        _autosave = null;
        _error = 'The last game cannot be continued: ${e.message}.';
      });
    }
  }

  void _open(LoadedSave loaded) {
    _play(context, GameController(assets: widget.assets, saves: widget.saves, game: loaded.game, orders: loaded.orders, marches: loaded.marches));
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.assets.geometry.size;
    final autosave = _autosave;
    final seat = autosave == null ? null : widget.assets.nationOf(autosave.scenario, autosave.nation);
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
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: AtlasText.body.copyWith(color: AtlasColors.signalText))),
              if (autosave != null) ...[
                FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 60)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('CONTINUE'),
                    Text(
                      '${seat?.shortName ?? 'Watching'}, ${autosave.date}',
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

/// A scenario to play, as a tab over the map: its year and its name.
class _ScenarioTab extends StatelessWidget {
  const _ScenarioTab(this.world, {required this.selected, required this.onTap});

  final World world;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceTile(
      selected: selected,
      onTap: onTap,
      label: '${world.startYear}, ${world.scenarioName}',
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('${world.startYear}', style: AtlasText.figure.copyWith(color: selected ? AtlasColors.brassBright : AtlasColors.ivoryDim)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(world.scenarioName, style: AtlasText.note.copyWith(color: selected ? AtlasColors.ivory : AtlasColors.ivoryDim), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

/// One setting of a new game: tapping it steps to the next choice.
class _Setting extends StatelessWidget {
  const _Setting({required this.label, required this.value, required this.note, required this.onTap});

  final String label;
  final String value;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value. Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: AtlasColors.brass)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label.toUpperCase(), style: AtlasText.label, maxLines: 1)),
              const Icon(Icons.unfold_more, size: 16, color: AtlasColors.brass),
            ]),
            const SizedBox(height: 3),
            Text(value, style: AtlasText.figure.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(note, style: AtlasText.note.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
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
  static const _difficulties = ['Easy', 'Normal', 'Hard'];

  late World _world = widget.assets.world;
  late MapScene _scene = _sceneFor(_world);
  late final MapCamera _camera = MapCamera(widget.assets.geometry.size);
  final MapOverlay _overlay = MapOverlay();

  /// The opening position, to read each nation's strength from.
  late Game _opening = Game.start(_world, human: -1, seed: 0);
  int _nation = 0;
  double _winFraction = Rules.defaultWinFraction;
  int _difficulty = Rules.normalDifficulty;
  bool _fog = false;
  bool _events = true;

  MapScene _sceneFor(World world) => MapScene(widget.assets.geometry, world)..setOwners(world.startOwners);

  @override
  void initState() {
    super.initState();
    _overlay.capitals = {for (final n in _world.nations) n.capital};
    _pick(_nation, center: false);
  }

  /// Switches to another scenario, keeping the player's nation when it
  /// exists there too.
  void _chooseScenario(World world) {
    if (world == _world) return;
    final current = _world.nations[_nation];
    final old = _scene;
    setState(() {
      _world = world;
      _scene = _sceneFor(world);
      _opening = Game.start(world, human: -1, seed: 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _overlay.capitals = {for (final n in world.nations) n.capital};
    final same = world.nations.where((n) => n.tag == current.tag || n.shortName == current.shortName).firstOrNull;
    _pick(same?.id ?? 0);
  }

  @override
  void dispose() {
    _scene.dispose();
    _camera.dispose();
    _overlay.dispose();
    super.dispose();
  }

  void _pick(int nation, {bool center = true}) {
    final capital = _world.nations[nation].capital;
    setState(() => _nation = nation);
    _overlay
      ..selected = capital
      ..changed();
    if (center && _camera.isLaidOut) _camera.reveal(widget.assets.geometry.provinces[capital].label, margin: 90);
  }

  void _begin() {
    final game = Game.start(
      _world,
      human: _nation,
      seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      winFraction: _winFraction,
      difficulty: _difficulty,
      fog: _fog,
      randomEvents: _events,
    );
    final controller = GameController(assets: widget.assets, saves: widget.saves, game: game)..autosave();
    _play(context, controller);
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    final nation = world.nations[_nation];
    final enemies = [
      for (final other in world.nations)
        if (_opening.atWar(_nation, other.id)) other.shortName,
    ];
    final provinces = world.provinces.length;
    final allyNames = [for (final a in _opening.alliesOf(_nation)) world.nations[a].shortName];
    final allies = allyNames.length > 4 ? '${allyNames.take(3).join(', ')} and ${allyNames.length - 3} more' : allyNames.join(', ');
    final length = _lengths.indexWhere((l) => l.$2 == _winFraction);
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
        if (widget.assets.scenarios.length > 1)
          Container(
            color: AtlasColors.baizeDeep,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              for (final scenario in widget.assets.scenarios) ...[
                if (scenario != widget.assets.scenarios.first) const SizedBox(width: 8),
                Expanded(child: _ScenarioTab(scenario, selected: scenario == _world, onTap: () => _chooseScenario(scenario))),
              ],
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
              NationFlag(nation, height: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nation.name, style: AtlasText.place, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    enemies.isEmpty ? 'At peace with everyone' : 'At war with ${enemies.join(', ')}',
                    style: AtlasText.note.copyWith(color: enemies.isEmpty ? AtlasColors.ivoryDim : AtlasColors.signalText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (allies.isNotEmpty) Text('Allied with $allies', style: AtlasText.note, maxLines: 2, overflow: TextOverflow.ellipsis),
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
            Row(children: [
              Expanded(
                child: _Setting(
                  label: 'To win',
                  value: '${(_winFraction * provinces).ceil()} provinces',
                  note: _lengths[length].$1,
                  onTap: () => setState(() => _winFraction = _lengths[(length + 1) % _lengths.length].$2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Setting(
                  label: 'Difficulty',
                  value: _difficulties[_difficulty],
                  note: 'AI income ${(Rules.aiIncome[_difficulty] * 100).round()}%',
                  onTap: () => setState(() => _difficulty = (_difficulty + 1) % _difficulties.length),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _Setting(
                  label: 'Fog of war',
                  value: _fog ? 'On' : 'Off',
                  note: _fog ? 'Armies near you' : 'All armies seen',
                  onTap: () => setState(() => _fog = !_fog),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Setting(
                  label: 'Random events',
                  value: _events ? 'On' : 'Off',
                  note: _events ? 'Strikes, harvests' : 'None by chance',
                  onTap: () => setState(() => _events = !_events),
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
