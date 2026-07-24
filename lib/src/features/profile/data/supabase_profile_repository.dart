import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../domain/profile_model.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository({this.client});

  final supabase.SupabaseClient? client;

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
      return ProfileModel.fromJson(response.first);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProfile(ProfileModel profile) async {
    final Map<String, dynamic> data = profile.toJson();
    data['user_created_at'] ??= DateTime.now().toIso8601String();

    await _supabase.from('profiles').upsert(data, onConflict: 'user_id');
  }

  @override
  Future<bool> hasCompletedProfile(String userId) async {
    final ProfileModel? profile = await getProfile(userId);
    if (profile == null) return false;
    return (profile.firstName?.isNotEmpty ?? false) &&
        (profile.lastName?.isNotEmpty ?? false) &&
        (profile.primaryLanguage?.isNotEmpty ?? false);
  }
}
