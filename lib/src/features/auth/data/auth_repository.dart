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
  Future<void> signOut();
}
