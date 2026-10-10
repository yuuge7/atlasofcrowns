import 'package:flutter/material.dart';

/// The table the game is played on: green baize, brass fittings, ivory
/// lettering, and the two pencils of a staff map.
abstract final class AtlasColors {
  static const baize = Color(0xFF1F3D36);
  static const baizeDeep = Color(0xFF142924);
  static const baizeLight = Color(0xFF2C5449);

  static const brass = Color(0xFFC8A24A);
  static const brassBright = Color(0xFFE6C877);

  static const ivory = Color(0xFFEFE7D3);
  static const ivoryDim = Color(0xFFAFB5A2);

  /// Red pencil: the enemy, attacks, war.
  static const signal = Color(0xFFC7402F);

  /// Blue pencil: your own movements.
  static const staffBlue = Color(0xFF2F6FBF);

  static const sea = Color(0xFFA8C5CB);
  static const seaLine = Color(0xFFB9D2D6);
  static const coast = Color(0xFF41626C);
  static const ink = Color(0xFF1E2725);
}

abstract final class AtlasFonts {
  /// Old Standard: the face of early 1900s atlases and scientific print.
  static const display = 'OldStandard';

  /// Barlow Condensed: figures and labels that must stay legible when small.
  static const data = 'BarlowCondensed';
}

abstract final class AtlasText {
  static const title = TextStyle(fontFamily: AtlasFonts.display, fontSize: 22, color: AtlasColors.ivory, height: 1.15);
  static const place = TextStyle(fontFamily: AtlasFonts.display, fontSize: 20, color: AtlasColors.ivory, height: 1.1);
  static const body = TextStyle(fontFamily: AtlasFonts.display, fontSize: 15, color: AtlasColors.ivory, height: 1.35);
  static const note = TextStyle(fontFamily: AtlasFonts.display, fontStyle: FontStyle.italic, fontSize: 14, color: AtlasColors.ivoryDim, height: 1.3);

  /// Small spaced capitals above a value or a group.
  static const label = TextStyle(fontFamily: AtlasFonts.data, fontWeight: FontWeight.w500, fontSize: 12, letterSpacing: 1.4, color: AtlasColors.ivoryDim, height: 1.1);
  static const figure = TextStyle(fontFamily: AtlasFonts.data, fontWeight: FontWeight.w600, fontSize: 20, color: AtlasColors.ivory, height: 1.05);
  static const button = TextStyle(fontFamily: AtlasFonts.data, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 1.2, height: 1.1);
}

ThemeData buildAtlasTheme() {
  const scheme = ColorScheme.dark(
    primary: AtlasColors.brass,
    onPrimary: AtlasColors.baizeDeep,
    secondary: AtlasColors.brassBright,
    onSecondary: AtlasColors.baizeDeep,
    surface: AtlasColors.baize,
    onSurface: AtlasColors.ivory,
    error: AtlasColors.signal,
    onError: AtlasColors.ivory,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(5));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AtlasColors.baizeDeep,
    fontFamily: AtlasFonts.display,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(bodyMedium: AtlasText.body, bodyLarge: AtlasText.body, titleLarge: AtlasText.title),
    dividerTheme: const DividerThemeData(color: AtlasColors.baizeLight, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AtlasColors.brass,
        foregroundColor: AtlasColors.baizeDeep,
        disabledBackgroundColor: AtlasColors.baizeLight,
        disabledForegroundColor: AtlasColors.ivoryDim,
        textStyle: AtlasText.button,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AtlasColors.brassBright,
        disabledForegroundColor: AtlasColors.ivoryDim,
        side: const BorderSide(color: AtlasColors.brass),
        textStyle: AtlasText.button,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AtlasColors.brassBright, textStyle: AtlasText.button, minimumSize: const Size(48, 48), shape: shape),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AtlasColors.brassBright, minimumSize: const Size(48, 48))),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AtlasColors.brass,
      inactiveTrackColor: AtlasColors.baizeLight,
      thumbColor: AtlasColors.brassBright,
      overlayColor: Color(0x33C8A24A),
      trackHeight: 3,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AtlasColors.baize,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: AtlasColors.brass)),
      titleTextStyle: AtlasText.title,
      contentTextStyle: AtlasText.body,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AtlasColors.baize,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AtlasColors.baizeDeep,
      contentTextStyle: AtlasText.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: const BorderSide(color: AtlasColors.brass)),
    ),
  );
}

/// Black or ivory, whichever reads on [background].
Color inkOn(Color background) => background.computeLuminance() > 0.36 ? AtlasColors.ink : AtlasColors.ivory;
