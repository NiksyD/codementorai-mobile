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

  /// Emails a password reset link. On mobile the link opens the app
  /// (codementorai://login-callback); on web it opens the web reset page.
  Future<void> resetPasswordForEmail({required String email});
  Future<void> updatePassword({required String newPassword});
  Future<void> signOut();
}
