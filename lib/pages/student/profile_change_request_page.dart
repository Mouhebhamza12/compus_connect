import 'package:compus_connect/utilities/colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileChangeRequestPage extends StatefulWidget {
  const ProfileChangeRequestPage({super.key});

  @override
  State<ProfileChangeRequestPage> createState() => _ProfileChangeRequestPageState();
}

class _ProfileChangeRequestPageState extends State<ProfileChangeRequestPage> {
  final _nameCtrl = TextEditingController();
  final _studentNumberCtrl = TextEditingController();
  final _majorCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentNumberCtrl.dispose();
    _majorCtrl.dispose();
    _yearCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = "You are not signed in.";
        _loading = false;
      });
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('full_name, email')
          .eq('user_id', user.id)
          .maybeSingle();

      final student = await client
          .from('students')
          .select('student_number, major, year')
          .eq('user_id', user.id)
          .maybeSingle();

      final pending = await client
          .from('profile_change_requests')
          .select('id, full_name, student_number, major, year, email, status, note, created_at')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();

      final Map<String, dynamic>? pendingMap = pending != null ? Map<String, dynamic>.from(pending as Map) : null;
      final Map<String, dynamic>? profileMap = profile != null ? Map<String, dynamic>.from(profile as Map) : null;
      final Map<String, dynamic>? studentMap = student != null ? Map<String, dynamic>.from(student as Map) : null;

      setState(() {
        _pending = pendingMap;
        _nameCtrl.text = (pendingMap?['full_name'] ?? profileMap?['full_name'] ?? '').toString();
        _emailCtrl.text = (pendingMap?['email'] ?? profileMap?['email'] ?? '').toString();
        _studentNumberCtrl.text = (pendingMap?['student_number'] ?? studentMap?['student_number'] ?? '').toString();
        _majorCtrl.text = (pendingMap?['major'] ?? studentMap?['major'] ?? '').toString();
        _yearCtrl.text = (pendingMap?['year'] ?? studentMap?['year'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() => _error = "You are not signed in.");
      return;
    }
    if (_pending != null) {
      setState(() => _error = "You already have a pending request.");
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final studentNumber = _studentNumberCtrl.text.trim();
    final major = _majorCtrl.text.trim();
    final yearText = _yearCtrl.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);

    if (yearText.isNotEmpty && year == null) {
      setState(() => _error = "Year must be a number.");
      return;
    }

    if ([name, email, studentNumber, major, yearText].every((e) => e.isEmpty)) {
      setState(() => _error = "Enter at least one field to change.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final inserted = await client
          .from('profile_change_requests')
          .insert({
            'user_id': user.id,
            'full_name': name.isNotEmpty ? name : null,
            'email': email.isNotEmpty ? email : null,
            'student_number': studentNumber.isNotEmpty ? studentNumber : null,
            'major': major.isNotEmpty ? major : null,
            'year': year,
          })
          .select()
          .single();

      setState(() {
        _pending = Map<String, dynamic>.from(inserted);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request submitted. Await admin review.")),
        );
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '23505') {
        setState(() => _error = "You already have a pending request.");
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Profile Change"),
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryNavy,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _pending != null
                          ? "You have a pending request. You will be notified once an admin reviews it."
                          : "Request updates to your name, student number, email, major, or year. An admin will review before changes go live.",
                      style: const TextStyle(color: kPrimaryNavy, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field("Full name", _nameCtrl, Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _field("Campus email", _emailCtrl, Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field("Student number", _studentNumberCtrl, Icons.confirmation_number_outlined),
                  const SizedBox(height: 12),
                  _field("Major", _majorCtrl, Icons.school_outlined),
                  const SizedBox(height: 12),
                  _field("Year", _yearCtrl, Icons.event_outlined, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting || _pending != null ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Submit request",
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                  if (_pending != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Submitted on ${DateTime.tryParse((_pending?['created_at'] ?? '').toString())?.toLocal().toString().split('.').first ?? ''}",
                      style: const TextStyle(color: kPrimaryNavy, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kInputGray),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kAccentBlue.withOpacity(0.7)),
        ),
      ),
    );
  }
}
