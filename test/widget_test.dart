import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kengai/repositories/auth_repository.dart';
import 'package:kengai/repositories/profile_repository.dart';
import 'package:kengai/screens/login_screen.dart';
import 'package:kengai/screens/profile_setup_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Stream<bool> get isSignedInStream => const Stream.empty();

  @override
  String? get currentUserId => null;

  @override
  Future<void> sendEmailOtp(String email) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<bool> hasProfile() async => false;

  @override
  Future<void> createProfile(String displayName) async {}

  @override
  Future<String> fetchDisplayName() async => 'テスト太郎';

  @override
  Future<void> setIntroPhoto(Uint8List originalPhotoBytes) async {}

  @override
  Future<Uint8List?> fetchIntroPhoto() async => null;
}

void main() {
  testWidgets('未ログイン時はメールアドレス入力欄が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authRepository: FakeAuthRepository()),
      ),
    );

    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('ログイン用リンクを送る'), findsOneWidget);
  });

  testWidgets('プロフィール作成画面に表示名入力欄が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupScreen(
          profileRepository: FakeProfileRepository(),
          onCreated: () {},
        ),
      ),
    );

    expect(find.text('表示名'), findsOneWidget);
    expect(find.text('決定'), findsOneWidget);
  });
}
