import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notes_app_correct/login.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseDatabase.instance.databaseURL = 'https://noteapp-21fc4-default-rtdb.asia-southeast1.firebasedatabase.app';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockLyte',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E3A8A),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF475569),
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
           titleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        textTheme: TextTheme(
          headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
          bodyMedium: GoogleFonts.inter(color: const Color(0xFF475569)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
         textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1E3A8A),
          ),
        ),
         checkboxTheme: CheckboxThemeData(
           checkColor: WidgetStateProperty.all(Colors.white),
          fillColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
         )
      ),
      home: const LoginPage(),
    );
  }
}
