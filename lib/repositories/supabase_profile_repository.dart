import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/garakei_photo_service.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'mail-photos';

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

  @override
  Future<void> setIntroPhoto(Uint8List originalPhotoBytes) async {
    final userId = _client.auth.currentUser!.id;

    // 原則どおり、元の写真は送らない。端末内でガラケー加工する。
    final processed = await GarakeiPhotoService.process(originalPhotoBytes);

    // 設定し直すたびに別名にして、送信済みの1通目を後から変えないようにする。
    final path = '$userId/intro-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          processed,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    await _client
        .from('profiles')
        .update({'intro_photo_path': path}).eq('id', userId);
  }

  @override
  Future<Uint8List?> fetchIntroPhoto() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select('intro_photo_path')
        .eq('id', userId)
        .single();
    final path = row['intro_photo_path'] as String?;
    if (path == null) return null;
    return _client.storage.from(_bucket).download(path);
  }
}
