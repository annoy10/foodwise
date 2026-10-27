import 'package:flutter/material.dart';
import 'services/api.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() => runApp(const FoodWiseApp());

class FoodWiseApp extends StatefulWidget {
  const FoodWiseApp({super.key});
  @override
  State<FoodWiseApp> createState() => _FoodWiseAppState();
}

class _FoodWiseAppState extends State<FoodWiseApp> {
  final api = Api();
  bool loggedIn = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'FoodWise',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7FAF7),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF248648)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
      cardTheme: CardThemeData(
        color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE5EBE5))),
      ),
    ),
    home: loggedIn
        ? HomeScreen(api: api, onLogout: () => setState(() { api.token = null; loggedIn = false; }))
        : AuthScreen(api: api, onLogin: () => setState(() => loggedIn = true)),
  );
}
