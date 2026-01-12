import 'package:compus_connect/bloc/auth_bloc.dart';
import 'package:compus_connect/pages/admin/admin_home.dart';
import 'package:compus_connect/pages/app_loading.dart';
import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/pages/student/student_home.dart';
import 'package:compus_connect/pages/teacher_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoleGate extends StatelessWidget {
  final Widget fallback;

  const RoleGate({super.key, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.initial ||
            state.status == AuthStatus.checking ||
            state.status == AuthStatus.loading) {
          return const AppLoadingPage(message: 'Checking your session...');
        }

        if (state.status == AuthStatus.authenticated && state.session != null) {
          switch (state.session!.role) {
            case 'student':
              return StudentHomePage(
                fullName: state.session!.fullName,
                studentNumber: state.session!.studentNumber,
                major: state.session!.major,
                year: state.session!.year,
                email: state.session!.email,
                photoUrl: state.session!.photoUrl,
                validity: state.session!.validity,
              );
            case 'teacher':
              return const TeacherHomePage();
            case 'admin':
              return const AdminHomePage();
            default:
              return _error(
                context,
                state.message ?? 'No role found for this account.',
              );
          }
        }

        if (state.status == AuthStatus.failure) {
          return fallback;
        }

        return fallback;
      },
    );
  }

  Widget _error(BuildContext context, String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text('Go to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
