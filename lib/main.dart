import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  static const _themeKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    _carregarTema();
  }

  Future<void> _carregarTema() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(_themeKey);
    if (salvo == 'dark' && mounted) {
      setState(() => _themeMode = ThemeMode.dark);
    }
  }

  void _toggleTheme() async {
    final novo = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = novo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, novo == ThemeMode.dark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestão Financeira',
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001529),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161B22),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF001529),
          indicatorColor: Colors.teal.shade700,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Colors.white, fontSize: 12);
            }
            return TextStyle(color: Colors.grey[400], fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return IconThemeData(color: Colors.grey[400]);
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF21262D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF001529),
          foregroundColor: Colors.white,
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.teal.shade800;
              return const Color(0xFF21262D);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.grey[400];
            }),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.teal;
            return Colors.grey[400];
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.teal.shade800;
            return Colors.grey[700];
          }),
        ),
      ),
      home: MainScreen(onToggleTheme: _toggleTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}
