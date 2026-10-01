import 'package:flutter/material.dart';

import '../models/friend.dart';
import '../repositories/friend_repository.dart';
import 'qr_display_screen.dart';
import 'qr_scan_screen.dart';

// 友達一覧と、QRの表示・読み取りへの入口。
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.friendRepository});

  final FriendRepository friendRepository;

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
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(friends[index].displayName),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
