import 'package:flutter/material.dart';

import '../data/save_store.dart';
import '../game/game_controller.dart';
import '../map/map_view.dart';
import '../theme.dart';
import 'dispatches.dart';
import 'main_menu.dart';
import 'province_sheet.dart';
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
  final _sheet = GlobalKey();
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..addListener(() {
      _c.overlay
        ..flash = 1 - Curves.easeOut.transform(_flash.value)
        ..changed();
    });
  int _revealed = -1;

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
  /// province the player is dealing with out from under it.
  void _measure() {
    if (!mounted) return;
    final top = (_topBar.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;
    final bottom = _c.selected >= 0 ? (_sheet.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0 : 0.0;
    if (top != _c.camera.topInset || bottom != _c.camera.bottomInset) _c.camera.setInsets(top: top, bottom: bottom);
    // While an attack or march is being sized, the target matters more.
    final focus = _c.mode == InputMode.moveAmount ? _c.moveTarget : _c.selected;
    if (focus != _revealed) {
      _revealed = focus;
      if (focus >= 0) _c.camera.reveal(_c.assets.geometry.provinces[focus].label);
    }
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
          await _c.saves.saveNew(_c.game, _c.orders);
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
    final next = GameController(assets: _c.assets, saves: _c.saves, game: loaded.game, orders: loaded.orders);
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: next)));
  }

  String _seat() => _c.human >= 0 ? _c.world.nations[_c.human].shortName : 'Watching';

  void _showPowers() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      builder: (context) => _Powers(_c, onLocate: (province) {
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
            child: KeyedSubtree(key: _topBar, child: _TopBar(c, onMenu: _openMenu, onDispatches: () => showDispatches(context, c), onPowers: _showPowers)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 12, 12 + (c.selected < 0 ? safeBottom : 0)),
                child: FilledButton(
                  onPressed: _endTurn,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(132, 56),
                    elevation: 6,
                    shadowColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: const BorderSide(color: AtlasColors.baizeDeep, width: 1.5)),
                  ),
                  child: Text(c.commanding ? 'END TURN' : 'NEXT MONTH', style: AtlasText.button.copyWith(fontSize: 18)),
                ),
              ),
              KeyedSubtree(key: _sheet, child: SizedBox(width: double.infinity, child: ProvinceSheet(c))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(this.controller, {required this.onMenu, required this.onDispatches, required this.onPowers});

  final GameController controller;
  final VoidCallback onMenu;
  final VoidCallback onDispatches;
  final VoidCallback onPowers;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final date = c.world.dateLabel(c.state.turn);
    final nation = c.human >= 0 ? c.world.nations[c.human] : null;
    final net = c.commanding ? c.income - c.upkeep : 0;
    final offers = c.peaceOffers.length;
    return Panel(
      padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top + 6, 4, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (nation != null) ...[NationSwatch(Color(nation.color), height: 30), const SizedBox(width: 10)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.commanding ? nation!.name : 'Watching the war', style: AtlasText.title.copyWith(fontSize: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          IconButton(onPressed: onPowers, icon: const Icon(Icons.public), tooltip: 'The powers'),
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu), tooltip: 'Menu'),
        ]),
        if (c.commanding)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Stat('Gold', '${c.goldFree}', detail: '${net >= 0 ? '+' : ''}$net a turn', detailColor: net >= 0 ? AtlasColors.ivoryDim : const Color(0xFFF08A75)),
              ),
              Expanded(flex: 3, child: Stat('Army', '${c.game.unitsOf(c.human)}')),
              Expanded(flex: 4, child: Stat('Provinces', '${c.game.provinceCount(c.human)}', detail: 'of ${c.game.winTarget} to win')),
            ]),
          ),
      ]),
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
    final nations = [
      for (final n in c.world.nations)
        if (c.state.alive[n.id]) n,
    ]..sort((a, b) => c.game.provinceCount(b.id) - c.game.provinceCount(a.id));
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('The powers', style: AtlasText.title),
                Text('${c.game.winTarget} of ${c.world.provinces.length} provinces win the war', style: AtlasText.note),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
          ]),
        ),
        const Divider(color: AtlasColors.brass),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: nations.length,
            itemBuilder: (context, i) {
              final n = nations[i];
              final String standing;
              var color = AtlasColors.ivoryDim;
              if (n.id == c.human) {
                standing = 'You';
                color = AtlasColors.brassBright;
              } else if (!c.commanding) {
                standing = '';
              } else if (c.game.atWar(c.human, n.id)) {
                standing = c.game.hasPeaceOffer(n.id, c.human) ? 'Offers peace' : 'At war';
                color = const Color(0xFFF08A75);
              } else if (c.game.truceLeft(c.human, n.id) > 0) {
                standing = 'Truce ${c.game.truceLeft(c.human, n.id)}';
              } else {
                standing = 'Peace';
              }
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
                        Text('${c.game.provinceCount(n.id)} provinces, ${c.game.unitsOf(n.id)} units', style: AtlasText.note),
                      ]),
                    ),
                    Text(standing.toUpperCase(), style: AtlasText.label.copyWith(color: color)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
