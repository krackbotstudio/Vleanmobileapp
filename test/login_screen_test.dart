import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vclean_laundry/auth.dart';
import 'package:vclean_laundry/customer_api.dart';
import 'package:vclean_laundry/login_screen.dart';

class ControlledAuth implements CustomerAuth {
  int requests = 0, verifications = 0;
  final pending = Completer<String>();
  @override
  Future<String> requestOtp(String phone) {
    requests++;
    return pending.future;
  }

  @override
  Future<CustomerSession> verifyOtp(
    String phone,
    String code,
    String requestId,
  ) async {
    verifications++;
    expect(code, '012345');
    throw const ApiException('Code expired. Request a new code.', 400);
  }

  @override
  Future<CustomerSession> restore(String token) => throw UnimplementedError();
}

void main() {
  testWidgets('one send at a time, six-digit OTP errors and resend cooldown', (
    tester,
  ) async {
    final auth = ControlledAuth();
    var now = DateTime(2026, 11, 5, 12);
    var authenticated = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginScreen(
            enableVideo: false,
            now: () => now,
            auth: auth,
            onAuthenticated: (_) async {
              authenticated = true;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('phone')), '9876543210');
    await tester.tap(find.byKey(const Key('send-otp')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-otp')));
    await tester.pump();
    expect(auth.requests, 1);
    auth.pending.complete('request');
    await tester.pumpAndSettle();
    final resend = tester.widget<OutlinedButton>(
      find.byKey(const Key('resend-otp')),
    );
    expect(resend.onPressed, isNull);
    for (final incomplete in ['1234', '12345']) {
      await tester.enterText(find.byKey(const Key('otp-code')), incomplete);
      await tester.tap(find.byKey(const Key('verify-otp')));
      await tester.pumpAndSettle();
      expect(auth.verifications, 0);
      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
    }
    await tester.enterText(find.byKey(const Key('otp-code')), '012345');
    await tester.tap(find.byKey(const Key('verify-otp')));
    await tester.pumpAndSettle();
    expect(auth.verifications, 1);
    expect(find.text('Code expired. Request a new code.'), findsOneWidget);
    expect(authenticated, isFalse);
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('resend-otp')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed delivery stays on phone entry without claiming a code was sent',
    (tester) async {
      final auth = ControlledAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(
              enableVideo: false,
              auth: auth,
              onAuthenticated: (_) async {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('phone')), '9876543210');
      await tester.tap(find.byKey(const Key('send-otp')));
      await tester.pump();
      auth.pending.completeError(
        const ApiException('Delivery is unavailable. Try again.', 503),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verification Code'), findsNothing);
      expect(find.text('Delivery is unavailable. Try again.'), findsOneWidget);
      expect(find.byKey(const Key('phone')), findsOneWidget);
    },
  );
}
