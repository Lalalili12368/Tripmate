import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash.dart';
import 'widgets.dart';

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sp = await SharedPreferences.getInstance();
  themeMode.value = (sp.getBool('dark') ?? false) ? ThemeMode.dark : ThemeMode.light;
  runApp(TripMateApp(loggedIn: sp.getInt('uid') != null));
}

ThemeData _theme(Brightness b) {
  final light = b == Brightness.light;
  var cs = ColorScheme.fromSeed(seedColor: kSage, brightness: b);
  if (light) {
    cs = cs.copyWith(
      primary: kSage,
      onPrimary: Colors.white,
      primaryContainer: kSageSoft,
      onPrimaryContainer: kSageDark,
      secondaryContainer: kSageSoft,
      surfaceContainerLow: Colors.white, // default Card colour
    );
  } else {
    cs = cs.copyWith(primary: const Color(0xFF9BB895), onPrimary: const Color(0xFF1B2D1C));
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: light ? kPaper : null,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? kPaper : null,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : null,
      indicatorColor: light ? kSageSoft : null,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: light ? kSage : cs.primary,
      foregroundColor: light ? Colors.white : cs.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      selectedColor: light ? kSage : null,
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      secondarySelectedColor: light ? kSage : null,
      checkmarkColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: light ? const Color(0xFFD5E0CF) : Colors.white24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
    ),
  );
}

class TripMateApp extends StatelessWidget {
  final bool loggedIn;
  const TripMateApp({super.key, required this.loggedIn});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (_, m, __) => MaterialApp(
          title: 'TripMate',
          debugShowCheckedModeBanner: false,
          themeMode: m,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: Splash(loggedIn: loggedIn),
        ),
      );
}
