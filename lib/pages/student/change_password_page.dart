import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:compus_connect/utilities/friendly_error.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _newPasswordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    setState(() {
      _error = null;
    });

    if (pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = "Please fill all fields.");
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = "Password must be at least 6 characters.");
      return;
    }
    if (pass != confirm) {
      setState(() => _error = "Passwords do not match.");
      return;
    }

    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception("Not signed in");
      final res = await client.auth.updateUser(UserAttributes(password: pass));
      if (res.user == null) throw Exception("Failed to update password");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e, fallback: 'Password update failed. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter a new password for your account.",
              style: TextStyle(color: Color(0xFF4B5A6B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm password",
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C78D1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Update password", style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
