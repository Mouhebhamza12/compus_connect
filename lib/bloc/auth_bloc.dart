import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus {
  initial,
  checking,
  loading,
  authenticated,
  unauthenticated,
  failure,
}

@immutable
class AuthSession {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String photoUrl;
  final String studentNumber;
  final String major;
  final String year;
  final String validity;

  const AuthSession({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.photoUrl,
    required this.studentNumber,
    required this.major,
    required this.year,
    required this.validity,
  });
}

@immutable
class AuthState {
  final AuthStatus status;
  final AuthSession? session;
  final String? message;

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.message,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? message,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      message: message,
    );
  }
}

@immutable
abstract class AuthEvent {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthState(status: AuthStatus.initial)) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.checking, message: null));
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('full_name, role, status, photo_url')
          .eq('user_id', session.user.id)
          .maybeSingle();

      final role = profile?['role']?.toString();
      final status = profile?['status']?.toString() ?? '';

      if (role == null || role.isEmpty) {
        emit(const AuthState(
          status: AuthStatus.failure,
          message: 'No role found for this account.',
        ));
        return;
      }

      if (status != 'active') {
        await client.auth.signOut();
        emit(const AuthState(
          status: AuthStatus.failure,
          message: 'Account pending admin approval.',
        ));
        return;
      }

      Map<String, dynamic>? student;
      if (role == 'student') {
        student = await client
            .from('students')
            .select('student_number, major, year')
            .eq('user_id', session.user.id)
            .maybeSingle();
      }

      emit(AuthState(
        status: AuthStatus.authenticated,
        session: _buildSession(
          user: session.user,
          profile: profile ?? {},
          student: student,
        ),
      ));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.failure,
        message: e.toString(),
      ));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, message: null));
    final client = Supabase.instance.client;

    try {
      final response = await client.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      final user = response.user;
      if (user == null) {
        emit(const AuthState(
          status: AuthStatus.failure,
          message: 'Login failed. No user session.',
        ));
        return;
      }

      final profile = await client
          .from('profiles')
          .select('status, role, full_name, photo_url')
          .eq('user_id', user.id)
          .single();

      if ((profile['status'] ?? '') != 'active') {
        await client.auth.signOut();
        emit(const AuthState(
          status: AuthStatus.failure,
          message: 'Your account is still pending admin approval.',
        ));
        return;
      }

      final role = profile['role'] as String?;
      if (role == null || role.isEmpty) {
        emit(const AuthState(
          status: AuthStatus.failure,
          message: 'No role set for this user.',
        ));
        return;
      }

      Map<String, dynamic>? student;
      if (role == 'student') {
        student = await client
            .from('students')
            .select('student_number, major, year')
            .eq('user_id', user.id)
            .maybeSingle();
      }

      emit(AuthState(
        status: AuthStatus.authenticated,
        session: _buildSession(
          user: user,
          profile: profile,
          student: student,
        ),
      ));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.failure,
        message: e.toString(),
      ));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await Supabase.instance.client.auth.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  AuthSession _buildSession({
    required User user,
    required Map<String, dynamic> profile,
    Map<String, dynamic>? student,
  }) {
    return AuthSession(
      userId: user.id,
      email: user.email ?? '',
      fullName: (profile['full_name'] ?? 'User').toString(),
      role: (profile['role'] ?? '').toString(),
      photoUrl: (profile['photo_url'] ?? '').toString(),
      studentNumber: (student?['student_number'] ?? 'N/A').toString(),
      major: (student?['major'] ?? '').toString(),
      year: (student?['year'] ?? '').toString(),
      validity: 'Active',
    );
  }
}
