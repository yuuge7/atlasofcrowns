import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/game_assets.dart';
import 'data/save_store.dart';
import 'theme.dart';
import 'ui/main_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The manifest locks the activity to portrait as well; this covers the
  // Flutter side.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AtlasApp());
}

class AtlasApp extends StatefulWidget {
  const AtlasApp({super.key});

  @override
  State<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends State<AtlasApp> {
  final Future<GameAssets> _assets = GameAssets.load();
  final SaveStore _saves = SaveStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas of Crowns',
      debugShowCheckedModeBanner: false,
      theme: buildAtlasTheme(),
      home: FutureBuilder<GameAssets>(
        future: _assets,
        builder: (context, snapshot) {
          final assets = snapshot.data;
          if (assets != null) return MainMenu(assets: assets, saves: _saves);
          return Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('The map could not be loaded.\n${snapshot.error}', style: AtlasText.body, textAlign: TextAlign.center),
                    )
                  : const Text('Unrolling the map', style: AtlasText.note),
            ),
          );
        },
      ),
    );
  }
}
