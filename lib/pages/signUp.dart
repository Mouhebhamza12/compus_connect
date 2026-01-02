import 'dart:io';

import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/utilities/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _loading = false;
  String? _error;

  final _fullNameController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _majorController = TextEditingController();
  final _yearController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _avatar;

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentNumberController.dispose();
    _majorController.dispose();
    _yearController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) {
      setState(() => _avatar = picked);
    }
  }

  Future<void> _handleSignUp() async {
  final fullName = _fullNameController.text.trim();
  final studentNumber = _studentNumberController.text.trim();
  final major = _majorController.text.trim();
  final year = _yearController.text.trim();
  final email = _emailController.text.trim();
  final password = _passwordController.text;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    if (fullName.isEmpty || studentNumber.isEmpty || email.isEmpty || password.isEmpty) {
      throw Exception('Name, student number, email, and password are required.');
    }

    final parsedYear = year.isNotEmpty ? int.tryParse(year) : null;
    if (year.isNotEmpty && parsedYear == null) {
      throw Exception('Year must be a number.');
    }

    final supabase = Supabase.instance.client;

    // 1) SIGN UP (user must be authenticated for storage upload)
    final authResponse = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = authResponse.user;
    if (user == null) throw Exception('Sign up failed. Please try again.');

    final userId = user.id;

    // 2) UPLOAD PHOTO (OPTIONAL) -> saves URL into profiles.photo_url
    String? photoUrl;

    if (_avatar != null) {
      final imageBytes = await _avatar!.readAsBytes();
      final path = '$userId/avatar.jpg';

      await supabase.storage.from('avatars').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      photoUrl = supabase.storage.from('avatars').getPublicUrl(path);
    }

    // 3) INSERT/UPSERT INTO profiles
    await supabase.from('profiles').upsert({
      'user_id': userId,
      'email': email,
      'role': 'student',
      'full_name': fullName,
      'status': 'pending',
      'photo_url': photoUrl, // can be null if no photo
    }, onConflict: 'user_id');

    // 4) INSERT/UPSERT INTO students
    await supabase.from('students').upsert({
      'user_id': userId,
      'student_number': studentNumber,
      'major': major.isNotEmpty ? major : null,
      'year': parsedYear,
    }, onConflict: 'user_id');

    if (!mounted) return;

    // 5) SIGN OUT (because they must wait for admin approval)
    await supabase.auth.signOut();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Await admin approval before signing in.')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _error = e.toString().replaceFirst('Exception: ', '');
    });
  } finally {
    if (!mounted) return;
    setState(() => _loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kPrimaryNavy, Color(0xFF0F1730)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              children: [
                                Image.asset(
                                  'assets/images/LogoWhite.png',
                                  width: 200,
                                  height: 200,
                                ),
                                Transform.translate(
                                  offset: const Offset(0, -36),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Campus Connect',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Create your student account (teachers are provisioned by the university)',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.55),
                                          fontSize: 12,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Use your campus email to sign up and unlock your digital ID.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Column(
                              children: [
                                GestureDetector(
                                  onTap: _loading ? null : _pickAvatar,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 46,
                                        backgroundColor: Colors.white,
                                        backgroundImage:
                                            _avatar != null ? FileImage(File(_avatar!.path)) : null,
                                        child: _avatar == null
                                            ? const Icon(Icons.camera_alt_outlined,
                                                size: 30, color: kPrimaryNavy)
                                            : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: kAccentBlue,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _avatar == null ? "Add a profile photo" : "Photo selected",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _inputField(
                                  icon: Icons.badge_outlined,
                                  hint: 'Full Name',
                                  obscure: false,
                                  controller: _fullNameController,
                                ),

                                const SizedBox(height: 12),

                                _inputField(
                                  icon: Icons.confirmation_number_outlined,
                                  hint: 'Student Number',
                                  obscure: false,
                                  controller: _studentNumberController,
                                ),

                                const SizedBox(height: 12),

                                _inputField(
                                  icon: Icons.school_outlined,
                                  hint: 'Major (optional)',
                                  obscure: false,
                                  controller: _majorController,
                                ),

                                const SizedBox(height: 12),

                                _inputField(
                                  icon: Icons.event_outlined,
                                  hint: 'Year (e.g. 3)',
                                  obscure: false,
                                  controller: _yearController,
                                  keyboardType: TextInputType.number,
                                ),

                                const SizedBox(height: 12),

                                _inputField(
                                  icon: Icons.person_outline,
                                  hint: 'Campus Email',
                                  obscure: false,
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                ),

                                const SizedBox(height: 12),

                                _inputField(
                                  icon: Icons.lock_outline,
                                  hint: 'Password',
                                  obscure: true,
                                  controller: _passwordController,
                                ),

                                const SizedBox(height: 18),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _handleSignUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAccentBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Create Student Account',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                  ),
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 14),

                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const LoginPage(),
                                            ),
                                          );
                                        },
                                  child: const Text(
                                    'Already have an account? Sign in',
                                    style: TextStyle(
                                      color: kLinkBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== INPUT FIELD =====
  Widget _inputField({
    required IconData icon,
    required String hint,
    required bool obscure,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        obscureText: obscure,
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: kPrimaryNavy, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: kInputGray),
          hintText: hint,
          hintStyle: const TextStyle(color: kInputGray),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: kAccentBlue.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }
}
