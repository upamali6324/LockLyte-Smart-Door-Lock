import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notes_app_correct/home.dart';

class CommonPasswordPage extends StatefulWidget {
  const CommonPasswordPage({super.key});

  @override
  State<CommonPasswordPage> createState() => _CommonPasswordPageState();
}

class _CommonPasswordPageState extends State<CommonPasswordPage> {
  final _pinController = TextEditingController();
  String? _errorMessage;
  int _remainingAttempts = 3;
  bool _pinVisible = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _sendAdminAlert() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final adminSnapshot = await FirebaseDatabase.instance.ref('admins').get();
      if (!adminSnapshot.exists) return;

      final adminsMap = adminSnapshot.value as Map<dynamic, dynamic>;
      final adminUids = adminsMap.keys.cast<String>().toList();

      await FirebaseFirestore.instance.collection('mail').add({
        'toUids': adminUids,
        'message': {
          'subject': 'LockLyte Security Alert: Unauthorized Access Attempt',
          'text':
              'A user with the email ${user.email} failed to enter the PIN three times. The app has been automatically closed for security.',
        },
      });
    } catch (e) {
      // Removed print statement for production code.
    }
  }

  Future<void> _verifyPin() async {
    final navigator = Navigator.of(context);
    final enteredPin = _pinController.text;
    if (enteredPin.isEmpty) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('lock_control/main_door/key_pad_pin')
          .get();

      if (snapshot.exists && snapshot.value.toString() == enteredPin) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _remainingAttempts--;
          if (_remainingAttempts > 0) {
            _errorMessage =
                'Incorrect PIN. $_remainingAttempts attempt(s) left.';
            _pinController.clear();
          } else {
            _sendAdminAlert();
            SystemNavigator.pop();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error verifying PIN. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 80, color: Color(0xFF1E90FF)),
                const SizedBox(height: 20),
                const Text(
                  "Access Verification",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter the PIN to continue",
                  style: TextStyle(
                    color: Colors.blueGrey.shade300,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _pinController,
                  obscureText: !_pinVisible,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: const TextStyle(color: Color(0x80FFFFFF)),
                    errorText: _errorMessage,
                    errorStyle: const TextStyle(color: Colors.redAccent),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    prefixIcon: const Icon(Icons.vpn_key_outlined,
                        color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _pinVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _pinVisible = !_pinVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x991E90FF),
                        blurRadius: 15,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E90FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _verifyPin,
                    child: const Text(
                      "ENTER",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
