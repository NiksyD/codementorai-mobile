import '../domain/user_model.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
}
