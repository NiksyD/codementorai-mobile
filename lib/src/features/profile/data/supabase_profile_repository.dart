import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../domain/profile_model.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository({this.client});

  final supabase.SupabaseClient? client;
  static ProfileModel? cachedProfile;

  supabase.SupabaseClient get _supabase =>
      client ?? supabase.Supabase.instance.client;

  @override
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .limit(1);

      if (response.isEmpty) return null;
      final ProfileModel p = ProfileModel.fromJson(response.first);
      cachedProfile = p;
      return p;
    } catch (_) {
      return cachedProfile;
    }
  }

  @override
  Future<void> saveProfile(ProfileModel profile) async {
    final Map<String, dynamic> data = profile.toJson();
    data['user_created_at'] ??= DateTime.now().toIso8601String();

    await _supabase.from('profiles').upsert(data, onConflict: 'user_id');

    // Also persist language and skill level in Auth user metadata
    try {
      await _supabase.auth.updateUser(
        supabase.UserAttributes(
          data: <String, dynamic>{
            'primary_language': profile.primaryLanguage,
            'skill_level': profile.skillLevel,
          },
        ),
      );
    } catch (_) {
      // Non-blocking metadata sync
    }
  }

  @override
  Future<bool> hasCompletedProfile(String userId) async {
    final ProfileModel? profile = await getProfile(userId);
    if (profile == null) return false;
    return (profile.firstName?.isNotEmpty ?? false) &&
        (profile.lastName?.isNotEmpty ?? false);
  }
}
