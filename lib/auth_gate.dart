import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:notes_app_correct/common_password_page.dart';
import 'package:notes_app_correct/login.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If a user is logged in, show the common password page.
        if (snapshot.hasData) {
          return const CommonPasswordPage();
        }

        // If no user is logged in, show the login screen.
        return const LoginPage();
      },
    );
  }
}
