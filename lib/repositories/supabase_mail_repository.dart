import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mail.dart';
import '../services/garakei_photo_service.dart';
import 'mail_repository.dart';

class SupabaseMailRepository implements MailRepository {
  SupabaseMailRepository(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'mail-photos';

  // 一度に取得するメールの上限。無限スクロールにはしない。
  static const int _conversationLimit = 100;

  @override
  Future<List<Mail>> fetchConversation(String friendId) async {
    final myId = _client.auth.currentUser!.id;

    // 自分と相手の間でやり取りされたメールだけを取る。
    final rows = await _client
        .from('mails')
        .select()
        .or('and(sender_id.eq.$myId,receiver_id.eq.$friendId),'
            'and(sender_id.eq.$friendId,receiver_id.eq.$myId)')
        .order('created_at', ascending: true)
        .limit(_conversationLimit);

    return [
      for (final row in rows as List)
        Mail(
          id: row['id'] as String,
          senderId: row['sender_id'] as String,
          receiverId: row['receiver_id'] as String,
          isMine: row['sender_id'] == myId,
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
