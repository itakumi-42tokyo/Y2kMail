import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend.dart';
import 'friend_repository.dart';

class SupabaseFriendRepository implements FriendRepository {
  SupabaseFriendRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> issueExchangeToken() async {
    final res = await _client.functions.invoke('issue-exchange-token');
    final data = res.data as Map<String, dynamic>;
    return data['token'] as String;
  }

  @override
  Future<RedeemResult> redeemToken(String token) async {
    try {
      await _client.functions.invoke(
        'redeem-exchange-token',
        body: {'token': token},
      );
      return RedeemResult.success;
    } on FunctionException catch (e) {
      // Edge Functionが返したエラーメッセージで、結果の種類を判定する。
      final details = e.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : '';
      if (e.status == 409 || message.contains('すでに友達')) {
        return RedeemResult.alreadyFriends;
      }
      if (message.contains('使用済み')) return RedeemResult.used;
      if (message.contains('有効期限')) return RedeemResult.expired;
      if (message.contains('自分')) return RedeemResult.selfQr;
      if (message.contains('無効')) return RedeemResult.invalid;
      return RedeemResult.error;
    } catch (_) {
      return RedeemResult.error;
    }
  }

  @override
  Future<List<Friend>> fetchFriends() async {
    final myId = _client.auth.currentUser!.id;

    // 自分が関わる友達関係を取得（RLSで自分の分だけ見える）。
    final rows = await _client
        .from('friendships')
        .select('user_a_id, user_b_id');

    // 相手側のIDを集める。
    final otherIds = <String>[];
    for (final row in rows as List) {
      final a = row['user_a_id'] as String;
      final b = row['user_b_id'] as String;
      otherIds.add(a == myId ? b : a);
    }
    if (otherIds.isEmpty) return [];

    // 相手の表示名をまとめて取得（友達のprofilesはRLSで見える）。
    final profiles = await _client
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', otherIds);

    return [
      for (final p in profiles as List)
        Friend(
          id: p['id'] as String,
          displayName: p['display_name'] as String,
        ),
    ];
  }
}
