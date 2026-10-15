import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../domain/profile_model.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository({this.client});

  final supabase.SupabaseClient? client;
  static ProfileModel? cachedProfile;
  static final ValueNotifier<ProfileModel?> profileChangeNotifier =
      ValueNotifier<ProfileModel?>(null);

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

      if (response.isEmpty) {
        final authUser = _supabase.auth.currentUser;
        if (authUser != null && authUser.id == userId) {
          final meta = authUser.userMetadata ?? <String, dynamic>{};
          final ProfileModel fallback = ProfileModel(
            userId: userId,
            email: authUser.email ?? '',
            firstName: (meta['first_name'] as String?) ?? (meta['full_name'] as String?)?.split(' ').first,
            lastName: (meta['last_name'] as String?) ?? ((meta['full_name'] as String?)?.contains(' ') == true ? (meta['full_name'] as String).split(' ').sublist(1).join(' ') : null),
            avatarUrl: (meta['avatar_url'] as String?) ?? (meta['picture'] as String?),
            role: (meta['role'] as String?) ?? 'student',
          );
          cachedProfile = fallback;
          return fallback;
        }
        return null;
      }
      final Map<String, dynamic> row = Map<String, dynamic>.from(response.first);
      final authUser = _supabase.auth.currentUser;
      if (authUser != null && authUser.id == userId) {
        final meta = authUser.userMetadata ?? <String, dynamic>{};
        if ((row['user_avatar_url'] as String?)?.trim().isNotEmpty != true) {
          row['user_avatar_url'] = (meta['avatar_url'] as String?) ?? (meta['picture'] as String?);
        }
        if ((row['user_first_name'] as String?)?.trim().isNotEmpty != true) {
          row['user_first_name'] = (meta['first_name'] as String?) ?? (meta['full_name'] as String?)?.split(' ').first;
        }
        if ((row['user_last_name'] as String?)?.trim().isNotEmpty != true) {
          row['user_last_name'] = (meta['last_name'] as String?) ?? ((meta['full_name'] as String?)?.contains(' ') == true ? (meta['full_name'] as String).split(' ').sublist(1).join(' ') : null);
        }
      }
      final ProfileModel p = ProfileModel.fromJson(row);
      cachedProfile = p;
      return p;
    } catch (_) {
      return cachedProfile;
    }
  }

  @override
  Future<void> saveProfile(ProfileModel profile) async {
    // Optimistically update memory cache and notify active listeners (e.g. Dashboard)
    cachedProfile = profile;
    profileChangeNotifier.value = profile;

    final Map<String, dynamic> data = profile.toJson();
    data['user_created_at'] ??= DateTime.now().toIso8601String();

    await _supabase.from('profiles').upsert(data, onConflict: 'user_id');

    // Also persist avatar, names, language, and skill level in Auth user metadata
    try {
      final Map<String, dynamic> metaUpdate = <String, dynamic>{
        'primary_language': profile.primaryLanguage,
        'skill_level': profile.skillLevel,
      };
      if (profile.avatarUrl?.trim().isNotEmpty == true) {
        metaUpdate['avatar_url'] = profile.avatarUrl;
        metaUpdate['picture'] = profile.avatarUrl;
      }
      if (profile.firstName?.trim().isNotEmpty == true) {
        metaUpdate['first_name'] = profile.firstName;
      }
      if (profile.lastName?.trim().isNotEmpty == true) {
        metaUpdate['last_name'] = profile.lastName;
      }

      await _supabase.auth.updateUser(
        supabase.UserAttributes(
          data: metaUpdate,
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
