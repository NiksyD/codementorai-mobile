import '../domain/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel?> getProfile(String userId);
  Future<void> saveProfile(ProfileModel profile);
  Future<bool> hasCompletedProfile(String userId);
}
