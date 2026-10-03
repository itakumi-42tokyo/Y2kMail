import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mail.dart';
import '../services/garakei_photo_service.dart';
import '../util/uuid.dart';
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
    // メールIDは端末側で生成（二重送信を同じIDの重複としてサーバーで弾く）。
    final id = uuidV4();

    String? photoPath;
    Uint8List? processed;
    if (originalPhotoBytes != null) {
      // 原則どおり、元の写真はサーバーに送らない。端末内でガラケー加工する。
      processed = await GarakeiPhotoService.process(originalPhotoBytes);
      // パスはIDから決める（再送時に同じパスへ上書きする）。
      photoPath = '$myId/$id.jpg';
    }

    final payload = buildMailInsert(
      id: id,
      senderId: myId,
      receiverId: receiverId,
      subject: subject,
      body: body,
      photoPath: photoPath,
    );

    await _withAuthRetry(() async {
      if (processed != null) {
        await _client.storage.from(_bucket).uploadBinary(
              photoPath!,
              processed,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
      }
      try {
        await _client.from('mails').insert(payload);
      } on PostgrestException catch (e) {
        // 同じIDが既にある＝送信済み。二重送信防止として成功扱い。
        if (e.code == '23505') return;
        rethrow;
      }
    });
  }

  // 送信ペイロードの組み立て（空文字はnull化）。テストしやすいよう純粋関数にする。
  static Map<String, dynamic> buildMailInsert({
    required String id,
    required String senderId,
    required String receiverId,
    String? subject,
    String? body,
    String? photoPath,
  }) {
    final s = subject?.trim();
    final b = body?.trim();
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'subject': (s == null || s.isEmpty) ? null : s,
      'body': (b == null || b.isEmpty) ? null : b,
      'photo_path': photoPath,
    };
  }

  // 認証(401/JWT)起因のエラーか。判定をテストできるよう切り出す。
  static bool isAuthError(Object e) {
    if (e is AuthException) return true;
    if (e is PostgrestException) {
      final code = e.code;
      if (code == '401' || code == 'PGRST301') return true;
      return e.message.toLowerCase().contains('jwt');
    }
    if (e is StorageException) {
      return e.statusCode == '401';
    }
    return false;
  }

  // 認証エラーなら、セッションを更新して1回だけ再試行する。
  // 更新自体に失敗したら SessionExpiredException を投げる。
  Future<void> _withAuthRetry(Future<void> Function() op) async {
    try {
      await op();
      return;
    } catch (e) {
      if (!isAuthError(e)) rethrow;
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        throw SessionExpiredException();
      }
      await op(); // 1回だけ再送
    }
  }

  @override
  Future<Uint8List> downloadPhoto(String photoPath) {
    return _client.storage.from(_bucket).download(photoPath);
  }
}
