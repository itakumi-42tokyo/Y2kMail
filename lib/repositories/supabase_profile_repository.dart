import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> hasProfile() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> createProfile(String displayName) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('profiles').insert({
      'id': userId,
      'display_name': displayName,
    });
  }

  @override
  Future<String> fetchDisplayName() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', userId)
        .single();
    return row['display_name'] as String;
  }
}
