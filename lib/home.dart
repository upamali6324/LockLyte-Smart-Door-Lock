import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notes_app_correct/common_password_page.dart';
import 'package:notes_app_correct/login.dart';
import 'package:notes_app_correct/manage_users_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isAdmin = false;
  final Set<String> _adminUids = {};
  late final StreamSubscription<DatabaseEvent> _adminSubscription;
  AppLifecycleState? _lastLifecycleState;

  final DatabaseReference _lockRef =
      FirebaseDatabase.instance.ref('lock_control/main_door');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final DatabaseReference _adminsRef = FirebaseDatabase.instance.ref('admins');

  late AnimationController _lockAnimationController;
  late Animation<double> _lockGlow;

  Map<String, String> _fingerprintIdToEmail = {};

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
    _listenToUsers();
    WidgetsBinding.instance.addObserver(this);

    _lockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _lockGlow = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(
      parent: _lockAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _adminSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _lockAnimationController.dispose();
    super.dispose();
  }

  void _listenToUsers() {
    _usersRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists) {
        final usersMap = event.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, String> tempMap = {};
        for (var entry in usersMap.entries) {
          final userData = entry.value as Map<dynamic, dynamic>;
          final email = userData['email'] as String?;
          final fingerprintId = userData['fingerprintId'] as String?;
          if (email != null &&
              fingerprintId != null &&
              fingerprintId.isNotEmpty) {
            tempMap[fingerprintId] = email;
          }
        }
        if (mounted) {
          setState(() {
            _fingerprintIdToEmail = tempMap;
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _lastLifecycleState == AppLifecycleState.paused) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CommonPasswordPage()),
        );
      }
    }
    _lastLifecycleState = state;
  }

  void _fetchAdminData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _adminSubscription = _adminsRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists) {
        final adminsMap = event.snapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            _adminUids.clear();
            _adminUids.addAll(adminsMap.keys.cast<String>());
            _isAdmin = _adminUids.contains(user.uid);
          });
        }
      }
    });
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _setLockStatus(bool isLocked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _lockRef.update({
      'isLocked': isLocked,
      'lastChanged': DateTime.now().toIso8601String(),
      'lastChangedBy': user.email,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 10,
        shadowColor: const Color(0x801E90FF),
        title: Row(
          children: const [
            Icon(Icons.lock_outline, color: Color(0xFF1E90FF)),
            SizedBox(width: 8),
            Text(
              'LockLyte Dashboard',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_outlined, color: Colors.white70),
            tooltip: 'Change Password',
            onPressed: () => _showChangeOwnPasswordDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLockStatusPanel(),
          const SizedBox(height: 20),
          _buildUserListPanel(),
          const SizedBox(height: 20),
          if (_isAdmin) _buildAdminPanel(),
        ],
      ),
    );
  }

  Widget _buildLockStatusPanel() {
    return _animatedCard(
      Column(
        children: [
          StreamBuilder<DatabaseEvent>(
            stream: _lockRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _errorCard(snapshot.error.toString());
              }
              if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
                return _infoCard('Awaiting lock status...');
              }

              final data =
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final bool isLocked = data['isLocked'] ?? true;
              final lastChanged = DateTime.parse(
                  data['lastChanged'] ?? DateTime.now().toIso8601String());
              final formattedTime =
                  DateFormat('MMM d, yyyy - hh:mm a').format(lastChanged);

              String lastChangedBy = data['lastChangedBy'] ?? 'Unknown';
              if (_fingerprintIdToEmail.containsKey(lastChangedBy)) {
                lastChangedBy = _fingerprintIdToEmail[lastChangedBy]!;
              }

              return Column(
                children: [
                  ScaleTransition(
                    scale: _lockGlow,
                    child: Icon(
                      isLocked ? Icons.lock : Icons.lock_open,
                      color: isLocked ? Colors.redAccent : Colors.greenAccent,
                      size: 90,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Door is ${isLocked ? "Locked" : "Unlocked"}',
                    style: TextStyle(
                      color: isLocked ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _infoBox(Icons.person, 'Last User', lastChangedBy),
                  _infoBox(Icons.timer, 'Last Activity', formattedTime),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _glowButton(
                          'Lock',
                          Icons.lock,
                          Colors.redAccent,
                          isLocked ? null : () => _setLockStatus(true)),
                      _glowButton('Unlock', Icons.lock_open, Colors.greenAccent,
                          !isLocked ? null : () => _setLockStatus(false)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserListPanel() {
    return _animatedCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Authorized Users',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: StreamBuilder<DatabaseEvent>(
              stream: _usersRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorCard(snapshot.error.toString());
                }
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return _infoCard('No users found.');
                }

                final usersMap =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final userEntries = usersMap.entries.toList();

                return ListView.builder(
                  itemCount: userEntries.length,
                  itemBuilder: (context, index) {
                    final user = userEntries[index];
                    final userData = user.value as Map<dynamic, dynamic>;
                    final bool isUserAdmin =
                        _adminUids.contains(user.key as String);

                    return ListTile(
                      leading: Icon(
                        isUserAdmin ? Icons.star : Icons.person_outline,
                        color: isUserAdmin
                            ? Colors.amberAccent
                            : Colors.blueGrey[300],
                      ),
                      title: Text(userData['email'] ?? 'No email',
                          style: const TextStyle(color: Colors.white70)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPanel() {
    return _animatedCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Tools',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _adminToolTile(
              Icons.pin, 'Change PIN', () => _showChangePinDialog(context)),
          const SizedBox(height: 10),
          _adminToolTile(Icons.group_add, 'Add/Delete Users', () {
            if (mounted) {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ManageUsersPage()));
            }
          }),
        ],
      ),
    );
  }

  Widget _glowButton(
      String label, IconData icon, Color color, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(color: color.withAlpha(128), blurRadius: 20, spreadRadius: 1)
      ]),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _infoBox(IconData icon, String title, String subtitle) {
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1E90FF)),
        title: Text(title, style: const TextStyle(color: Colors.white70)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _animatedCard(Widget child) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, double value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)), child: _glassCard(child)),
        );
      },
    );
  }

  Widget _glassCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4D1E90FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261E90FF),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _adminToolTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      tileColor: const Color(0xFF161B22),
      leading: Icon(icon, color: const Color(0xFF1E90FF)),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      onTap: onTap,
    );
  }

  Widget _infoCard(String message) {
    return _glassCard(
        Center(child: Text(message, style: const TextStyle(color: Colors.white70))));
  }

  Widget _errorCard(String message) {
    return _glassCard(
        Center(child: Text(message, style: const TextStyle(color: Colors.redAccent))));
  }

  void _showChangePinDialog(BuildContext context) {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool pinVisible = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              title:
                  const Text('Change PIN', style: TextStyle(color: Colors.white)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newPinController,
                      autofocus: true,
                      obscureText: !pinVisible,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter new PIN',
                        hintStyle: const TextStyle(color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            pinVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              pinVisible = !pinVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'PIN cannot be empty' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPinController,
                      obscureText: !pinVisible,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Confirm new PIN',
                        hintStyle: const TextStyle(color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            pinVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              pinVisible = !pinVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != newPinController.text) {
                          return 'PINs do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70))),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isLoading = true);
                            try {
                              final newPin = newPinController.text;
                              // Update both Firestore and Realtime Database
                              await FirebaseFirestore.instance
                                  .collection('app_secrets')
                                  .doc('common_password')
                                  .update({'password': newPin});
                              await _lockRef.update({'key_pad_pin': newPin});

                              if (!mounted) return;
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('PIN changed successfully!'),
                                    backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => isLoading = false);
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeOwnPasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool passwordVisible = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              title: const Text('Change Password',
                  style: TextStyle(color: Colors.white)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      autofocus: true,
                      obscureText: !passwordVisible,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Current Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              passwordVisible = !passwordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Password cannot be empty' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: !passwordVisible,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'New Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              passwordVisible = !passwordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value!.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: !passwordVisible,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Confirm New Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              passwordVisible = !passwordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70))),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isLoading = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser!;
                              final cred = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: currentPasswordController.text);

                              await user.reauthenticateWithCredential(cred);
                              await user.updatePassword(newPasswordController.text);

                              if (!mounted) return;
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Password changed successfully!'),
                                    backgroundColor: Colors.green),
                              );
                            } on FirebaseAuthException catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Error: ${e.message ?? "An unknown error occurred."}'),
                                    backgroundColor: Colors.red),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => isLoading = false);
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
