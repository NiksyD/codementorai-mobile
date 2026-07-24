import '../domain/user_model.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  });
  Future<void> signInWithGoogle();
  Future<void> signInWithGithub();
  Future<void> resetPasswordForEmail({required String email});
  Future<void> sendPasswordResetOtp({required String email});
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  });
  Future<void> updatePassword({required String newPassword});
  Future<void> signOut();
}
