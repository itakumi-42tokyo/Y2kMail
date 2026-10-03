import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mail.dart';
import '../services/garakei_photo_service.dart';
import 'mail_repository.dart';

class SupabaseMailRepository implements MailRepository {
  SupabaseMailRepository(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'mail-photos';

  @override
  Future<int> countInbox() => _count('receiver_id');

  @override
  Future<int> countOutbox() => _count('sender_id');

  Future<int> _count(String column) async {
    final myId = _client.auth.currentUser!.id;
    return _client.from('mails').count(CountOption.exact).eq(column, myId);
  }

  @override
  Future<List<Mail>> fetchInbox({required int page, required int pageSize}) =>
      _fetchPage(selfColumn: 'receiver_id', partnerColumn: 'sender_id',
          page: page, pageSize: pageSize);

  @override
  Future<List<Mail>> fetchOutbox({required int page, required int pageSize}) =>
      _fetchPage(selfColumn: 'sender_id', partnerColumn: 'receiver_id',
          page: page, pageSize: pageSize);

  Future<List<Mail>> _fetchPage({
    required String selfColumn,
    required String partnerColumn,
    required int page,
    required int pageSize,
  }) async {
    final myId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('mails')
        .select()
        .eq(selfColumn, myId)
        .order('created_at', ascending: false)
        .range(from, to) as List;

    // 相手の表示名をまとめて取得（友達のprofilesはRLSで見える）。
    final partnerIds = <String>{
      for (final r in rows) r[partnerColumn] as String,
    }.toList();
    final nameById = <String, String>{};
    if (partnerIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', partnerIds) as List;
      for (final p in profiles) {
        nameById[p['id'] as String] = p['display_name'] as String;
      }
    }

    return [
      for (final row in rows)
        Mail(
          id: row['id'] as String,
          partnerId: row[partnerColumn] as String,
          partnerName: nameById[row[partnerColumn]] ?? '(不明)',
          subject: row['subject'] as String?,
          body: row['body'] as String?,
          photoPath: row['photo_path'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  @override
  Future<void> sendMail({
    required String receiverId,
    String? subject,
    String? body,
    Uint8List? originalPhotoBytes,
  }) async {
    final myId = _client.auth.currentUser!.id;

    String? photoPath;
    if (originalPhotoBytes != null) {
      // 原則どおり、元の写真はサーバーに送らない。端末内でガラケー加工する。
      final processed = await GarakeiPhotoService.process(originalPhotoBytes);
      // 自分のフォルダにのみアップロードできる（Storageのポリシー）。
      photoPath = '$myId/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await _client.storage.from(_bucket).uploadBinary(
            photoPath,
            processed,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }

    final trimmedSubject = subject?.trim();
    final trimmedBody = body?.trim();

    await _client.from('mails').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'subject': (trimmedSubject == null || trimmedSubject.isEmpty)
          ? null
          : trimmedSubject,
      'body':
          (trimmedBody == null || trimmedBody.isEmpty) ? null : trimmedBody,
      'photo_path': photoPath,
    });
  }

  @override
  Future<Uint8List> downloadPhoto(String photoPath) {
    return _client.storage.from(_bucket).download(photoPath);
  }
}
