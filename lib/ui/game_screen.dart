import 'package:flutter/material.dart';

import '../data/save_store.dart';
import '../engine/orders.dart';
import '../game/game_controller.dart';
import '../map/map_view.dart';
import '../theme.dart';
import 'dispatches.dart';
import 'main_menu.dart';
import 'province_sheet.dart';
import 'research_sheet.dart';
import 'sheets.dart';
import 'widgets.dart';

/// The game itself: the map edge to edge, the stats bar on top, the province
/// sheet at the bottom and End turn under the right thumb.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  /// Owned by this screen and disposed with it.
  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _topBar = GlobalKey();

  /// The End turn button and the province sheet under it.
  final _bottomHud = GlobalKey();
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..addListener(() {
      _c.overlay
        ..flash = 1 - Curves.easeOut.transform(_flash.value)
        ..changed();
    });
  int _revealed = -1;
  double _revealedAbove = 0;

  GameController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onChanged);
    _flash.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-turn keeps the orders written so far.
    if (state == AppLifecycleState.paused) _c.autosave();
  }

  void _onChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Tells the camera how much of the screen the HUD covers, and slides the
  /// province the player is dealing with out from under it, again whenever
  /// the sheet grows over it.
  void _measure() {
    if (!mounted) return;
    final top = (_topBar.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;
    final bottom = _c.selected >= 0 ? (_bottomHud.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0 : 0.0;
    if (top != _c.camera.topInset || bottom != _c.camera.bottomInset) _c.camera.setInsets(top: top, bottom: bottom);
    // While an attack or march is being sized, the target matters more.
    final focus = _c.mode == InputMode.moveAmount ? _c.moveTarget : _c.selected;
    if (focus != _revealed || bottom > _revealedAbove) {
      _revealed = focus;
      if (focus >= 0) _c.camera.reveal(_c.assets.geometry.provinces[focus].label);
    }
    _revealedAbove = bottom;
  }

  void _endTurn() {
    _c.endTurn();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false) && _c.overlay.flashing.isNotEmpty) _flash.forward(from: 0);
    if (_c.state.ended) {
      _showGameOver();
    } else if (Dispatches(_c.lastReport!, _c.world, _c.human).yours.isNotEmpty) {
      showDispatches(context, _c);
    }
  }

  Future<void> _showGameOver() async {
    final s = _c.state;
    final String title;
    final String body;
    final String carryOn;
    if (s.winner >= 0 && s.winner == s.human) {
      title = 'Victory';
      body = 'You hold ${_c.game.provinceCount(s.human)} of ${_c.world.provinces.length} provinces. The war is yours, ${_c.world.dateLabel(s.turn)}.';
      carryOn = 'KEEP PLAYING';
    } else if (s.winner < 0) {
      title = 'Defeat';
      body = 'Your last province fell in ${_c.world.dateLabel(s.turn - 1)}. ${_c.world.nations[s.human].name} is no more.';
      carryOn = 'WATCH THE WAR GO ON';
    } else {
      final winner = _c.world.nations[s.winner];
      title = '${winner.shortName} has won';
      body = '${winner.name} holds ${_c.game.provinceCount(s.winner)} of ${_c.world.provinces.length} provinces, enough to decide the war.';
      carryOn = _c.commanding ? 'KEEP PLAYING' : 'KEEP WATCHING';
    }
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('MAIN MENU')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(carryOn)),
        ],
      ),
    );
    if (!mounted) return;
    if (leave ?? false) {
      _toMainMenu();
    } else {
      _c.keepPlaying();
    }
  }

  void _toMainMenu() {
    final assets = _c.assets;
    final saves = _c.saves;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => MainMenu(assets: assets, saves: saves)));
  }

  Future<void> _openMenu() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_c.world.dateLabel(_c.state.turn)}, turn ${_c.state.turn + 1}'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('BACK TO THE MAP')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('SAVE GAME')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'load'), child: const Text('LOAD GAME')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'rules'), child: const Text('HOW TO PLAY')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'quit'), child: const Text('MAIN MENU')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'save':
        final messenger = ScaffoldMessenger.of(context);
        try {
          await _c.saves.saveNew(_c.game, _c.orders, marches: _c.marchesToJson);
          messenger.showSnackBar(SnackBar(content: Text('Game saved: ${_seat()}, ${_c.world.dateLabel(_c.state.turn)}.')));
        } on Object catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('The game could not be saved: $e')));
        }
      case 'load':
        final loaded = await showLoadSheet(context, _c.assets, _c.saves);
        if (loaded != null && mounted) _open(loaded);
      case 'rules':
        showHowToPlay(context);
      case 'quit':
        // The turn so far is kept in the autosave.
        await _c.autosave();
        if (mounted) _toMainMenu();
    }
  }

  void _open(LoadedSave loaded) {
    final next = GameController(assets: _c.assets, saves: _c.saves, game: loaded.game, orders: loaded.orders, marches: loaded.marches);
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: next)));
  }

  String _seat() => _c.human >= 0 ? _c.world.nations[_c.human].shortName : 'Watching';

  void _showPowers() {
    showAtlasSheet<void>(
      context,
      (context) => _Powers(_c, onLocate: (province) {
        Navigator.pop(context);
        _c.camera.centerOn(_c.assets.geometry.provinces[province].label);
        _c.tapProvince(province);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final focus = c.commanding ? c.assets.geometry.provinces[c.state.capital[c.human]].label : null;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (c.mode != InputMode.browse) {
          c.cancelInput();
        } else if (c.selected >= 0) {
          c.tapProvince(-1);
        } else {
          _openMenu();
        }
      },
      child: Scaffold(
        backgroundColor: AtlasColors.sea,
        body: Stack(children: [
          Positioned.fill(
            child: MapView(scene: c.scene, camera: c.camera, overlay: c.overlay, onTapProvince: c.tapProvince, initialFocus: focus, initialZoom: 2.8),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: KeyedSubtree(
              key: _topBar,
              child: _TopBar(c, onMenu: _openMenu, onDispatches: () => showDispatches(context, c), onPowers: _showPowers, onResearch: () => showResearch(context, c)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(key: _bottomHud, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + (c.selected < 0 ? safeBottom : 0)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _MapModeButton(c),
                  const SizedBox(width: 10),
                  Expanded(child: Align(alignment: Alignment.bottomLeft, child: _Legend(c))),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _endTurn,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(132, 56),
                      elevation: 6,
                      shadowColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: const BorderSide(color: AtlasColors.baizeDeep, width: 1.5)),
                    ),
                    child: Text(c.commanding ? 'END TURN' : 'NEXT MONTH', style: AtlasText.button.copyWith(fontSize: 18)),
                  ),
                ]),
              ),
              SizedBox(width: double.infinity, child: ProvinceSheet(c)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(this.controller, {required this.onMenu, required this.onDispatches, required this.onPowers, required this.onResearch});

  final GameController controller;
  final VoidCallback onMenu;
  final VoidCallback onDispatches;
  final VoidCallback onPowers;
  final VoidCallback onResearch;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final date = c.world.dateLabel(c.state.turn);
    final nation = c.human >= 0 ? c.world.nations[c.human] : null;
    final net = c.commanding ? c.income - c.upkeep - c.researchSpend : 0;
    final offers = c.peaceOffers.length + c.allianceOffers.length;
    return Panel(
      padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top + 6, 4, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (nation != null) ...[NationSwatch(Color(nation.color), height: 30), const SizedBox(width: 10)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FirstThatFits(c.commanding ? [nation!.name, nation.shortName] : const ['Watching the war'], style: AtlasText.title.copyWith(fontSize: 19)),
              Text('$date, turn ${c.state.turn + 1}', style: AtlasText.note),
            ]),
          ),
          if (c.lastReport != null)
            Badge(
              isLabelVisible: offers > 0,
              label: Text('$offers'),
              backgroundColor: AtlasColors.signal,
              offset: const Offset(-6, 6),
              child: IconButton(onPressed: onDispatches, icon: const Icon(Icons.mail_outline), tooltip: 'Dispatches from last turn'),
            ),
          if (c.commanding) IconButton(onPressed: onResearch, icon: const Icon(Icons.science_outlined), tooltip: 'Research'),
          IconButton(onPressed: onPowers, icon: const Icon(Icons.public), tooltip: 'The powers'),
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu), tooltip: 'Menu'),
        ]),
        if (c.commanding)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Stat('Gold', '${c.goldFree}', detail: '${net >= 0 ? '+' : ''}$net a turn', detailColor: net >= 0 ? AtlasColors.ivoryDim : AtlasColors.signalText),
              ),
              Expanded(flex: 3, child: Stat('Army', '${c.army}')),
              Expanded(flex: 4, child: Stat('Provinces', '${c.game.provinceCount(c.human)}', detail: 'of ${c.game.winTarget} to win')),
            ]),
          ),
      ]),
    );
  }
}

/// Opens the choice of how the land is coloured.
class _MapModeButton extends StatelessWidget {
  const _MapModeButton(this.controller);

  final GameController controller;

  static String label(MapMode mode) => switch (mode) {
        MapMode.political => 'Political',
        MapMode.diplomacy => 'Diplomacy',
        MapMode.economy => 'Economy',
      };

  static String note(MapMode mode) => switch (mode) {
        MapMode.political => 'Who holds what',
        MapMode.diplomacy => 'Allies, enemies and truces',
        MapMode.economy => 'What each province yields',
      };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PopupMenuButton<MapMode>(
      tooltip: 'Map mode',
      onSelected: c.setMapMode,
      color: AtlasColors.baize,
      position: PopupMenuPosition.over,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: const BorderSide(color: AtlasColors.brass)),
      itemBuilder: (context) => [
        for (final mode in c.mapModes)
          PopupMenuItem(
            value: mode,
            child: Row(children: [
              SizedBox(width: 28, child: mode == c.mapMode ? const Icon(Icons.check, size: 18, color: AtlasColors.brassBright) : null),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label(mode), style: AtlasText.body),
                Text(note(mode), style: AtlasText.note.copyWith(fontSize: 12)),
              ]),
            ]),
          ),
      ],
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AtlasColors.baize,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AtlasColors.brass, width: 1.5),
          boxShadow: const [BoxShadow(color: AtlasColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: const Icon(Icons.layers_outlined, color: AtlasColors.brassBright),
      ),
    );
  }
}

/// What the colours mean, for every map mode but the political one.
class _Legend extends StatelessWidget {
  const _Legend(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    switch (controller.mapMode) {
      case MapMode.political:
        return const SizedBox.shrink();
      case MapMode.diplomacy:
        content = Wrap(spacing: 10, runSpacing: 4, children: [
          for (final relation in Relation.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              NationSwatch(relation.color, width: 10, height: 10),
              const SizedBox(width: 4),
              Text(relation.legend.toUpperCase(), style: AtlasText.label.copyWith(color: AtlasColors.ivory, letterSpacing: 0.8)),
            ]),
        ]);
      case MapMode.economy:
        content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('INCOME A TURN', style: AtlasText.label.copyWith(color: AtlasColors.ivory)),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              border: Border.all(color: AtlasColors.ink),
              gradient: const LinearGradient(colors: [AtlasColors.mapPoor, AtlasColors.mapMiddling, AtlasColors.mapRich]),
            ),
          ),
          const SizedBox(height: 2),
          Row(children: [
            Text('0', style: AtlasText.label.copyWith(fontSize: 11)),
            const Spacer(),
            Text('$incomeMiddling', style: AtlasText.label.copyWith(fontSize: 11)),
            const Spacer(),
            Text('${2 * incomeMiddling}+', style: AtlasText.label.copyWith(fontSize: 11)),
          ]),
        ]);
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: AtlasColors.baize.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AtlasColors.baizeLight),
      ),
      child: content,
    );
  }
}

/// Every nation still standing, strongest first, and how it stands with the player.
class _Powers extends StatelessWidget {
  const _Powers(this.controller, {required this.onLocate});

  final GameController controller;
  final ValueChanged<int> onLocate;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final held = List.filled(c.world.nations.length, 0);
    for (final o in c.state.owner) {
      held[o]++;
    }
    final nations = [
      for (final n in c.world.nations)
        if (c.state.alive[n.id]) n,
    ]..sort((a, b) => held[b.id] - held[a.id]);
    return AtlasSheet(
      title: 'The powers',
      note: '${c.game.winTarget} of ${c.world.provinces.length} provinces win the war',
      body: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: nations.length,
        itemBuilder: (context, i) {
          final n = nations[i];
          final army = c.armyOf(n.id);
          final (standing, color) = !c.commanding && n.id != c.human
              ? ('', AtlasColors.ivoryDim)
              : switch (c.relationTo(n.id)) {
                  Relation.you => ('You', AtlasColors.brassBright),
                  Relation.ally => ('Ally', AtlasColors.brassBright),
                  Relation.war => (c.game.hasPeaceOffer(n.id, c.human) ? 'Offers peace' : 'At war', AtlasColors.signalText),
                  Relation.truce => ('Truce ${c.game.truceLeft(c.human, n.id)}', AtlasColors.ivoryDim),
                  Relation.peace => (c.game.hasAllianceOffer(n.id, c.human) ? 'Offers alliance' : 'Peace', AtlasColors.ivoryDim),
                };
          return InkWell(
            onTap: () => onLocate(c.state.capital[n.id]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                NationSwatch(Color(n.color)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.name, style: AtlasText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${held[n.id]} provinces, ${army != null ? '$army units' : 'army unknown'}', style: AtlasText.note),
                    Text('Army ${c.game.techLevel(n.id, Field.army)}, industry ${c.game.techLevel(n.id, Field.industry)}', style: AtlasText.note),
                  ]),
                ),
                Text(standing.toUpperCase(), style: AtlasText.label.copyWith(color: color)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
