import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../domain/user_model.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository({this.client});

  final supabase.SupabaseClient? client;

  supabase.SupabaseClient get _supabase =>
      client ?? supabase.Supabase.instance.client;

  @override
  Future<User?> getCurrentUser() async {
    final supabase.User? user = _supabase.auth.currentUser;
    if (user == null) return null;
    return User(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final supabase.AuthResponse response = await _supabase.auth
        .signInWithPassword(email: email, password: password);

    final supabase.User? user = response.user;
    if (user == null) {
      throw Exception('Sign in failed: No user returned');
    }

    return User(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final supabase.AuthResponse response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? <String, dynamic>{'full_name': fullName} : null,
    );

    final supabase.User? user = response.user;
    if (user == null) {
      throw Exception('Registration failed: No user returned');
    }

    return User(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'codementorai://login-callback',
      authScreenLaunchMode: supabase.LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signInWithGithub() async {
    await _supabase.auth.signInWithOAuth(
      supabase.OAuthProvider.github,
      redirectTo: kIsWeb ? null : 'codementorai://login-callback',
      authScreenLaunchMode: supabase.LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> resetPasswordForEmail({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> sendPasswordResetOtp({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    final supabase.AuthResponse response = await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: supabase.OtpType.recovery,
    );

    if (response.session == null) {
      // Fallback for general OTP verification
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: supabase.OtpType.email,
      );
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await _supabase.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
