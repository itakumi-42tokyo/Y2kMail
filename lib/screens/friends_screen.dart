import 'package:flutter/material.dart';

import '../models/friend.dart';
import '../repositories/friend_repository.dart';
import '../repositories/mail_repository.dart';
import 'conversation_screen.dart';
import 'qr_display_screen.dart';
import 'qr_scan_screen.dart';

// 友達一覧と、QRの表示・読み取りへの入口。
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.friendRepository,
    required this.mailRepository,
  });

  final FriendRepository friendRepository;
  final MailRepository mailRepository;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<List<Friend>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _friendsFuture = widget.friendRepository.fetchFriends();
  }

  Future<void> _openDisplay() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QrDisplayScreen(friendRepository: widget.friendRepository),
      ),
    );
  }

  Future<void> _openScan() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(friendRepository: widget.friendRepository),
      ),
    );
    // 友達が増えたら一覧を更新する。
    if (added == true && mounted) {
      setState(_reload);
    }
  }

  // 開発用: カメラを使わず、トークンを手入力して友達追加を試す。
  // 動作確認が済んだら削除する。
  Future<void> _manualRedeem() async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('トークン手入力（開発用）'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '相手のトークンを貼り付け'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (token == null || token.isEmpty || !mounted) return;

    final result = await widget.friendRepository.redeemToken(token);
    if (!mounted) return;
    final message = switch (result) {
      RedeemResult.success => '友達になりました',
      RedeemResult.alreadyFriends => 'すでに友達です',
      RedeemResult.expired => 'QRコードの有効期限が切れています',
      RedeemResult.used => 'このQRコードは使用済みです',
      RedeemResult.selfQr => '自分のQRコードは読み取れません',
      RedeemResult.invalid => '無効なQRコードです',
      RedeemResult.error => '読み取りに失敗しました',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (result == RedeemResult.success) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('電話帳')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openDisplay,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QRを見せる'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QRを読み取る'),
                  ),
                ),
              ],
            ),
          ),
          // 開発用の入口。動作確認が済んだら削除する。
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _manualRedeem,
              child: const Text('トークン手入力（開発用）'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Friend>>(
              future: _friendsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('一覧の取得に失敗しました'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final friends = snapshot.data!;
                if (friends.isEmpty) {
                  return const Center(child: Text('まだ友達がいません。\nQRを交換して追加しましょう。'));
                }
                return ListView.separated(
                  itemCount: friends.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(friend.displayName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            mailRepository: widget.mailRepository,
                            friendId: friend.id,
                            friendName: friend.displayName,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
