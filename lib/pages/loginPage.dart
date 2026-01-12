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
    FocusScope.of(context).unfocus();

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
    final activeError = _error ?? authError;
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        if (state.status == AuthStatus.failure && state.message?.isNotEmpty == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
          return;
        }

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
        resizeToAvoidBottomInset: true,
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
                      final isCompact = constraints.maxHeight < 720;
                      final shouldScroll = constraints.maxHeight < 640;
                      final logoSize = isCompact ? 150.0 : 200.0;
                      final titleSize = isCompact ? 22.0 : 26.0;
                      final subtitleSize = isCompact ? 11.0 : 12.0;
                      final blurbSize = isCompact ? 11.0 : 12.0;
                      final sectionSpacing = isCompact ? 24.0 : 32.0;
                      final fieldSpacing = isCompact ? 12.0 : 14.0;
                      final rowSpacing = isCompact ? 10.0 : 12.0;
                      final buttonHeight = isCompact ? 46.0 : 50.0;

                      final content = Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - (isCompact ? 32 : 48),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/images/LogoWhite.png',
                                    width: logoSize,
                                    height: logoSize,
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -24),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Campus Connect',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: titleSize,
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
                                            fontSize: subtitleSize,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Stay connected to your studies.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: blurbSize,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: sectionSpacing),

                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _inputField(
                                    icon: Icons.person_outline,
                                    hint: 'Email / ID',
                                    obscure: false,
                                    controller: _emailController,
                                  ),

                                  SizedBox(height: fieldSpacing),

                                  _inputField(
                                    icon: Icons.lock_outline,
                                    hint: 'Password',
                                    obscure: true,
                                    controller: _passwordController,
                                  ),

                                  SizedBox(height: rowSpacing),

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

                                  SizedBox(height: isCompact ? 16 : 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
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

                                  if (activeError != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              activeError,
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 13,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
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

                      if (!shouldScroll) return content;

                      return SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: content,
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
