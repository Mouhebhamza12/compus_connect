import 'package:compus_connect/bloc/auth_bloc.dart';
import 'package:compus_connect/pages/admin/admin_home.dart';
import 'package:compus_connect/pages/signUp.dart';
import 'package:compus_connect/pages/student/student_home.dart';
import 'package:compus_connect/pages/teacher_home.dart';
import 'package:compus_connect/utilities/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _rememberMe = false;
  bool _resetting = false;
  String? _error;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Email and password are required.';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    context.read<AuthBloc>().add(
          AuthLoginRequested(email: email, password: password),
        );
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first to reset your password.')),
      );
      return;
    }
    setState(() {
      _resetting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isLoading =
        authState.status == AuthStatus.loading || authState.status == AuthStatus.checking;
    final authError = authState.status == AuthStatus.failure ? authState.message : null;
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated && state.session != null) {
          final session = state.session!;
          switch (session.role) {
            case 'student':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentHomePage(
                    fullName: session.fullName,
                    studentNumber: session.studentNumber,
                    major: session.major,
                    year: session.year,
                    email: session.email,
                    photoUrl: session.photoUrl,
                    validity: session.validity,
                  ),
                ),
                (_) => false,
              );
              break;
            case 'teacher':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const TeacherHomePage()),
                (_) => false,
              );
              break;
            case 'admin':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AdminHomePage()),
                (_) => false,
              );
              break;
            default:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No role found for this account.')),
              );
              context.read<AuthBloc>().add(const AuthLogoutRequested());
          }
        }
      },
      child: Scaffold(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 48,
                          ),
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
                                    offset: const Offset(0, -28),
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
                                          'Your Academic Hub',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.55),
                                            fontSize: 12,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'This is the login page for returning users.',
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

                              const SizedBox(height: 32),

                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _inputField(
                                    icon: Icons.person_outline,
                                    hint: 'Email / ID',
                                    obscure: false,
                                    controller: _emailController,
                                  ),

                                  const SizedBox(height: 14),

                                  _inputField(
                                    icon: Icons.lock_outline,
                                    hint: 'Password',
                                    obscure: true,
                                    controller: _passwordController,
                                  ),

                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        activeColor: kAccentBlue,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value!;
                                          });
                                        },
                                      ),
                                      const Text(
                                        'Remember Me',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kAccentBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: isLoading || _resetting ? null : _handleResetPassword,
                                      child: Text(
                                        _resetting ? 'Sending reset...' : 'Forgot password?',
                                        style: const TextStyle(color: Colors.white),
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
                                  ] else if (authError != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      authError,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const SignUpPage(),
                                              ),
                                            );
                                          },
                                    child: const Text(
                                      'Need a student account? Sign up',
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
      ),
    );
  }

  // ===== INPUT FIELD =====
  Widget _inputField({
    required IconData icon,
    required String hint,
    required bool obscure,
    required TextEditingController controller,
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        obscureText: obscure,
        controller: controller,
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
