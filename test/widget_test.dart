import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kengai/repositories/auth_repository.dart';
import 'package:kengai/screens/login_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Stream<bool> get isSignedInStream => const Stream.empty();

  @override
  String? get currentUserId => null;

  @override
  Future<void> sendEmailOtp(String email) async {}

  @override
  Future<void> sendPhoneOtp(String phone) async {}

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
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
}
