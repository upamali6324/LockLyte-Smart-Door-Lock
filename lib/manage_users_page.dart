import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:notes_app_correct/add_user_page.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage>
    with SingleTickerProviderStateMixin {
  final DatabaseReference usersRef = FirebaseDatabase.instance.ref('users');
  final DatabaseReference adminsRef = FirebaseDatabase.instance.ref('admins');
  Set<String> adminUids = {};

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    final snapshot = await adminsRef.get();
    if (snapshot.exists) {
      final adminsMap = snapshot.value as Map<dynamic, dynamic>;
      if (!mounted) return;
      setState(() {
        adminUids = adminsMap.keys.cast<String>().toSet();
      });
    }
  }

  Future<void> _toggleAdmin(String uid, bool makeAdmin) async {
    if (makeAdmin) {
      await adminsRef.child(uid).set(true);
    } else {
      await adminsRef.child(uid).remove();
    }
    if (!mounted) return;
    await _loadAdmins();
  }

  Future<void> _deleteUser(String uid) async {
    await usersRef.child(uid).remove();
    await adminsRef.child(uid).remove();
    if (!mounted) return;
    await _loadAdmins();
  }

  void _showDeleteUserDialog(String uid, String email) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "Delete User",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "Are you sure you want to delete the user $email?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await _deleteUser(uid);
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void _showEditFingerprintDialog(String uid, String currentFingerprintId) {
    final controller = TextEditingController(text: currentFingerprintId);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "Edit Fingerprint ID",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Fingerprint ID",
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF1E90FF)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyanAccent),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E90FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await usersRef.child(uid).child('fingerprintId').set(controller.text);
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        elevation: 12,
        backgroundColor: const Color(0xFF161B22),
        shadowColor: const Color(0x991E90FF),
        title: Row(
          children: const [
            Icon(Icons.manage_accounts, color: Color(0xFF1E90FF)),
            SizedBox(width: 10),
            Text(
              'Manage Users',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: usersRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E90FF)));
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
                child: Text('No users found.',
                    style: TextStyle(color: Colors.white70)));
          }

          final usersMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final users = usersMap.entries.toList();

          return FadeTransition(
            opacity: _fadeController,
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = user.key as String;
                final userData = user.value as Map<dynamic, dynamic>;
                final userEmail = userData['email'] ?? 'No email';
                final fingerprintId = userData['fingerprintId'] ?? '';
                final bool isAdmin = adminUids.contains(userId);

                return _buildUserCard(userEmail, isAdmin, userId, fingerprintId);
              },
            ),
          );
        },
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0xAA1E90FF),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF1E90FF),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddUserPage()),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildUserCard(
      String email, bool isAdmin, String uid, String fingerprintId) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAdmin ? Colors.amberAccent : const Color(0x441E90FF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isAdmin
                ? Colors.amberAccent.withOpacity(0.3)
                : const Color(0x441E90FF),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        leading: Icon(
          isAdmin ? Icons.star_rounded : Icons.person_outline_rounded,
          color: isAdmin ? Colors.amberAccent : Colors.cyanAccent,
          size: 32,
        ),
        title: Text(
          email,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Fingerprint ID: ${fingerprintId.isEmpty ? "Not Set" : fingerprintId}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: "Delete User",
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _showDeleteUserDialog(uid, email),
              ),
            ),
            Tooltip(
              message: "Edit Fingerprint ID",
              child: IconButton(
                icon:
                const Icon(Icons.fingerprint, color: Colors.lightBlueAccent),
                onPressed: () => _showEditFingerprintDialog(uid, fingerprintId),
              ),
            ),
            Tooltip(
              message: isAdmin ? "Remove Admin" : "Make Admin",
              child: IconButton(
                icon: Icon(
                  isAdmin ? Icons.remove_moderator : Icons.add_moderator,
                  color: isAdmin ? Colors.redAccent : Colors.greenAccent,
                ),
                onPressed: () async {
                  await _toggleAdmin(uid, !isAdmin);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
