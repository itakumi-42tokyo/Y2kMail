import 'package:flutter_test/flutter_test.dart';
import 'package:kengai/repositories/supabase_mail_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('buildMailInsert', () {
    test('空・空白の件名/本文はnullになる', () {
      final m = SupabaseMailRepository.buildMailInsert(
        id: 'ID1', senderId: 'S', receiverId: 'R',
        subject: '   ', body: '',
      );
      expect(m['subject'], isNull);
      expect(m['body'], isNull);
      expect(m['photo_path'], isNull);
      expect(m['id'], 'ID1');
      expect(m['sender_id'], 'S');
      expect(m['receiver_id'], 'R');
    });

    test('前後の空白はトリムされ、写真パスはそのまま入る', () {
      final m = SupabaseMailRepository.buildMailInsert(
        id: 'ID2', senderId: 'S', receiverId: 'R',
        subject: '  やあ  ', body: ' こんにちは ', photoPath: 'S/ID2.jpg',
      );
      expect(m['subject'], 'やあ');
      expect(m['body'], 'こんにちは');
      expect(m['photo_path'], 'S/ID2.jpg');
    });
  });

  group('isAuthError', () {
    test('401/JWT系はtrue', () {
      expect(
          SupabaseMailRepository.isAuthError(
              const PostgrestException(message: 'JWT expired', code: 'PGRST301')),
          isTrue);
      expect(
          SupabaseMailRepository.isAuthError(
              const PostgrestException(message: 'unauthorized', code: '401')),
          isTrue);
      expect(
          SupabaseMailRepository.isAuthError(
              const StorageException('x', statusCode: '401')),
          isTrue);
      expect(SupabaseMailRepository.isAuthError(const AuthException('expired')),
          isTrue);
    });

    test('RLS違反や重複はfalse（＝再送しない）', () {
      expect(
          SupabaseMailRepository.isAuthError(const PostgrestException(
              message: 'new row violates row-level security policy',
              code: '42501')),
          isFalse);
      expect(
          SupabaseMailRepository.isAuthError(
              const PostgrestException(message: 'duplicate key', code: '23505')),
          isFalse);
      expect(
          SupabaseMailRepository.isAuthError(
              const StorageException('x', statusCode: '403')),
          isFalse);
    });
  });
}
