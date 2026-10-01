import 'package:flutter/material.dart';

import '../repositories/profile_repository.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.profileRepository,
    required this.onCreated,
  });

  final ProfileRepository profileRepository;
  final VoidCallback onCreated;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = '表示名を入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.profileRepository.createProfile(name);
      widget.onCreated();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表示名を決める')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('相手に表示される名前です。あとから変更できます。'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 20,
              decoration: const InputDecoration(labelText: '表示名'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _createProfile,
              child: const Text('決定'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
