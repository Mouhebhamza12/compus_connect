import 'package:supabase_flutter/supabase_flutter.dart';

// Turns technical errors into short, friendly messages.
String friendlyError(Object error, {String? fallback}) {
  final mapped = _mapByType(error);
  if (mapped != null) return mapped;

  final raw = _cleanErrorText(error.toString());
  final mappedText = _mapFromText(raw);
  if (mappedText != null) return mappedText;

  if (fallback != null && fallback.trim().isNotEmpty) return fallback;
  if (_looksFriendly(raw)) return raw;

  return 'Something went wrong. Please try again.';
}

// Login-specific helper with a tighter fallback.
String friendlyAuthError(Object error) {
  return friendlyError(error, fallback: 'Sign in failed. Please try again.');
}

// Removes exception prefixes for display.
String cleanErrorMessage(Object error) {
  return _cleanErrorText(error.toString());
}

String? _mapByType(Object error) {
  if (error is AuthApiException) {
    return _mapAuthError(code: error.code, message: error.message);
  }
  if (error is AuthException) {
    return _mapAuthError(code: error.code, message: error.message);
  }
  if (error is PostgrestException) {
    return _mapPostgrestError(error);
  }
  if (error is StorageException) {
    return _mapStorageError(error.message);
  }
  return null;
}

String? _mapAuthError({String? code, String? message}) {
  final msg = (message ?? '').toLowerCase();
  final errCode = (code ?? '').toLowerCase();

  if (errCode == 'invalid_credentials' || errCode == 'invalid_login_credentials') {
    return 'Email or password is incorrect.';
  }
  if (errCode == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return 'Please verify your email before signing in.';
  }
  if (errCode == 'user_not_found' || msg.contains('user not found')) {
    return 'No account found for this email.';
  }
  if (errCode == 'signup_disabled' || msg.contains('signup') && msg.contains('disabled')) {
    return 'Sign up is currently disabled.';
  }
  if (errCode == 'weak_password' || msg.contains('password') && msg.contains('too short')) {
    return 'Password is too short. Use at least 6 characters.';
  }
  if (errCode == 'email_address_invalid' || msg.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  if (errCode == 'over_email_send_rate_limit' || errCode == 'too_many_requests') {
    return 'Too many attempts. Please try again later.';
  }
  if (msg.contains('invalid login credentials')) {
    return 'Email or password is incorrect.';
  }
  return null;
}

String? _mapPostgrestError(PostgrestException e) {
  if (e.code == '42P01' || e.code == 'PGRST205') {
    return 'This feature is not ready yet.';
  }
  if (e.message.toLowerCase().contains('permission') || e.message.toLowerCase().contains('rls')) {
    return 'You do not have permission to do this.';
  }
  return null;
}

String? _mapStorageError(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('bucket') && lower.contains('not')) {
    return 'File storage is not set up yet. Please contact support.';
  }
  if (lower.contains('permission') || lower.contains('rls')) {
    return 'You do not have permission to upload files.';
  }
  return null;
}

String? _mapFromText(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')) {
    return 'Email or password is incorrect.';
  }
  if (lower.contains('not signed in') || lower.contains('no user session')) {
    return 'Please sign in again.';
  }
  if (lower.contains('jwt') || lower.contains('session expired')) {
    return 'Your session expired. Please sign in again.';
  }
  if (lower.contains('socketexception') || lower.contains('failed host lookup')) {
    return 'No internet connection.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Request timed out. Please try again.';
  }
  if (lower.contains('permission') || lower.contains('rls')) {
    return 'You do not have permission to do this.';
  }
  return null;
}

String _cleanErrorText(String message) {
  var text = message.trim();
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  return text;
}

bool _looksFriendly(String message) {
  if (message.isEmpty) return false;
  final lower = message.toLowerCase();
  const techTokens = [
    'exception',
    'authapi',
    'postgrest',
    'socket',
    'stacktrace',
    'statuscode',
    'code:',
    'invalid_credentials',
    'jwt',
  ];
  for (final token in techTokens) {
    if (lower.contains(token)) return false;
  }
  return message.length <= 80;
}
