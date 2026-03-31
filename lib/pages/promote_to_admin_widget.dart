import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small widget you can drop into any admin/debug screen to promote a user
/// to role = 'admin' in Firestore (users/{uid}.role = 'admin') after entering
/// the master password stored in SharedPreferences under 'master_password'.
///
/// Usage:
/// - Place the widget anywhere (for example in AdminSettingsPage or AdminSalesPage).
/// - By default it promotes the currently signed-in user. You can pass
///   a `targetUid` to promote a specific uid (useful for admin panel).
///
/// Important security note:
/// - This only writes the `role` field to Firestore. For production-grade
///   authorization you should enforce server-side checks (Cloud Functions / Admin SDK,
///   custom claims). Don't expose this widget to regular users.
class PromoteToAdminButton extends StatefulWidget {
  /// If provided, the widget will promote this uid. Otherwise it promotes the current user.
  final String? targetUid;

  /// Optional label for the button.
  final String label;

  const PromoteToAdminButton({
    super.key,
    this.targetUid,
    this.label = 'Promote to admin (debug)',
  });

  @override
  State<PromoteToAdminButton> createState() => _PromoteToAdminButtonState();
}

class _PromoteToAdminButtonState extends State<PromoteToAdminButton> {
  bool _loading = false;

  Future<String> _readSavedMasterPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('master_password') ?? '987654';
  }

  Future<void> _showAndPromote() async {
    final TextEditingController passCtrl = TextEditingController();
    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Authorize promotion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter master password to promote user to admin'),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Master password'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm')),
          ],
        );
      },
    );

    if (result != true) return;

    final entered = passCtrl.text.trim();
    final saved = await _readSavedMasterPassword();
    if (entered != saved) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Incorrect master password'),
            backgroundColor: Colors.red));
      return;
    }

    String? uid = widget.targetUid;
    if (uid == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No signed-in user'), backgroundColor: Colors.red));
        return;
      }
      uid = user.uid;
    }

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': 'admin',
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User promoted to admin'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Promotion failed: $e'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _showAndPromote,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.upgrade),
      label: Text(widget.label),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
    );
  }
}
