import 'package:material_ui/material_ui.dart';

/// Эстетика школьной тетради в клетку: синяя, красная, зелёная ручки.
/// Шрифты: Nunito — основной текст, Caveat — «рукописные» заголовки,
/// NotoColorEmoji — эмодзи (подмножество, встроено в приложение).
class Fonts {
  Fonts._();
  static const body = 'Nunito';
  static const hand = 'Caveat';
  static const fallback = ['NotoColorEmoji'];
}

class Pen {
  Pen._();
  static const blue = Color(0xFF1F4FA3);
  static const red = Color(0xFFC62828);
  static const green = Color(0xFF2E7D32);
  static const pencil = Color(0xFF5F6368);
  static const paper = Color(0xFFFDFCF7);
  static const grid = Color(0xFFCFDDF0);
  static const margin = Color(0xFFE57373);
  static const sticker = Color(0xFFFFF59D);
  static const gold = Color(0xFFF2B705);
}

ThemeData buildNotebookTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Pen.blue,
    primary: Pen.blue,
    secondary: Pen.green,
    error: Pen.red,
    surface: Pen.paper,
  );
  return ThemeData(
    fontFamily: Fonts.body,
    fontFamilyFallback: Fonts.fallback,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pen.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Pen.paper,
      foregroundColor: Pen.blue,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: Fonts.hand,
        fontFamilyFallback: Fonts.fallback,
        color: Pen.blue,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: Pen.blue, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: Pen.blue, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: Pen.blue, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Color(0xFF263238)),
      bodyMedium: TextStyle(color: Color(0xFF263238)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Pen.grid),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pen.blue,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Pen.blue,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Pen.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: Pen.blue)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Pen.blue, width: 2)),
    ),
    chipTheme: const ChipThemeData(
      selectedColor: Color(0xFFDCE8F8),
      side: BorderSide(color: Pen.grid),
    ),
  );
}
