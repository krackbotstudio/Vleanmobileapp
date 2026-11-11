import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vclean_laundry/main.dart';
import 'package:vclean_laundry/brand_api.dart';
import 'package:vclean_laundry/auth.dart';
import 'package:vclean_laundry/catalog.dart';
import 'package:vclean_laundry/account_data.dart';
import 'package:vclean_laundry/customer_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<BrandInfo> brand() async => const BrandInfo(
  name: 'Vclean Laundry',
  privacy: 'Sample privacy policy',
  terms: 'Sample terms',
  branches: [Branch('one', 'Example branch')],
);
Future<List<String>> banners() async => [];

class FakeAuth implements CustomerAuth {
  int sent = 0;
  @override
  Future<String> requestOtp(String phone) async {
    sent++;
    return 'test-request';
  }

  @override
  Future<CustomerSession> verifyOtp(
    String phone,
    String code,
    String requestId,
  ) async => const CustomerSession(
    'test-token',
    CustomerProfile(id: 'customer', phone: '9876543210', name: 'Test customer'),
  );
  @override
  Future<CustomerSession> restore(String token) async => const CustomerSession(
    'test-token',
    CustomerProfile(id: 'customer', phone: '9876543210', name: 'Test customer'),
  );
}

Future<List<CatalogItem>> catalogue(String branch) async => const [
  CatalogItem(
    id: 'shoes',
    name: 'Canvas Shoes',
    prices: [CatalogPrice('SHOES', 'DRY CLEAN', 42550)],
  ),
  CatalogItem(
    id: 'shirt',
    name: 'Shirt',
    prices: [CatalogPrice('MEN', 'STEAM IRON', 2500)],
  ),
];

Future<void> start(
  WidgetTester tester, {
  double width = 390,
  Future<BrandInfo> Function()? loadBrand,
  FakeAuth? auth,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    DarkToWhiteApp(
      enableVideo: false,
      loadBrand: loadBrand ?? brand,
      loadBanners: banners,
      loadCatalogue: catalogue,
      auth: auth ?? FakeAuth(),
      accountApi: AccountApi(
        CustomerApi(
          MockClient(
            (request) async => http.Response(
              request.url.path.endsWith('/me')
                  ? '{"user":{"id":"customer","phone":"9876543210","role":"CUSTOMER","name":"Test customer"}}'
                  : '[]',
              200,
            ),
          ),
        ),
      ),
      sessionStore: MemorySessionStore(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> navigate(WidgetTester tester, int index) async {
  final skip = find.byKey(const Key('login-skip'));
  if (skip.evaluate().isNotEmpty) {
    await reveal(tester, skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('nav-$index')));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('latest login and four tabs lead to guest profile and policies', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Accept & Send OTP'), findsOneWidget);
    expect(find.text('Book Now'), findsNothing);
    expect(find.byKey(const Key('nav-0')), findsNothing);
    await navigate(tester, 0);
    for (var index = 0; index < 4; index++) {
      expect(find.byKey(Key('nav-$index')), findsOneWidget);
    }
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('home-continue')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('service-daily')), findsNothing);
    expect(find.text('Select pickup date'), findsOneWidget);
    await tester.tap(find.byTooltip('Toggle Dark/Light Mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Hello'))).brightness,
      Brightness.dark,
    );
    await navigate(tester, 3);
    expect(find.text('Welcome'), findsOneWidget);
    await reveal(tester, find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('Sample privacy policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone validation, OTP screen, verified profile and sign out', (
    tester,
  ) async {
    final auth = FakeAuth();
    await start(tester, auth: auth);
    await tester.tap(find.byKey(const Key('send-otp')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('phone')), '9876543210');
    await reveal(tester, find.byKey(const Key('send-otp')));
    await tester.tap(find.byKey(const Key('send-otp')));
    await tester.pumpAndSettle();
    expect(auth.sent, 1);
    expect(find.text('Verification Code'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('otp-code')), '012345');
    await reveal(tester, find.byKey(const Key('verify-otp')));
    await tester.tap(find.byKey(const Key('verify-otp')));
    await tester.pumpAndSettle();
    expect(find.text('Hello Test customer'), findsOneWidget);
    await navigate(tester, 3);
    expect(find.text('9876543210'), findsOneWidget);
    await reveal(tester, find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Accept & Send OTP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home schedule carries into the booking review and resets after saving',
    (tester) async {
      await start(tester, width: 320);
      // Sign in first — booking now requires authentication
      await tester.enterText(find.byKey(const Key('phone')), '9876543210');
      await reveal(tester, find.byKey(const Key('send-otp')));
      await tester.tap(find.byKey(const Key('send-otp')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('otp-code')), '012345');
      await reveal(tester, find.byKey(const Key('verify-otp')));
      await tester.tap(find.byKey(const Key('verify-otp')));
      await tester.pumpAndSettle();
      await navigate(tester, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('home-continue')))
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byKey(const Key('pickup-day-2')));
      await tester.tap(find.byKey(const Key('pickup-day-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('home-continue')))
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byKey(const Key('pickup-window-1')));
      await tester.tap(find.byKey(const Key('pickup-window-1')));
      await tester.pumpAndSettle();
      await navigate(tester, 1);
      await navigate(tester, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('home-continue')))
            .onPressed,
        isNotNull,
      );
      await reveal(tester, find.byKey(const Key('pickup-day-1')));
      await tester.tap(find.byKey(const Key('pickup-day-1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('home-continue')))
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byKey(const Key('pickup-window-1')));
      await tester.tap(find.byKey(const Key('pickup-window-1')));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final chosenDate = DateTime(now.year, now.month, now.day + 2);
      await reveal(tester, find.byKey(const Key('home-continue')));
      await tester.tap(find.byKey(const Key('home-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Pickup address'), findsWidgets);
      await reveal(tester, find.widgetWithText(FilledButton, 'Continue').last);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a complete pickup address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('address')),
        'Sample flat 10, Example Street',
      );
      await tester.enterText(find.byKey(const Key('postal')), '500001');
      final addressContinue = find
          .widgetWithText(FilledButton, 'Continue')
          .last;
      await reveal(tester, addressContinue);
      await tester.tap(addressContinue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Example branch'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm pickup'), findsOneWidget);
      expect(
        find.text('${chosenDate.day}/${chosenDate.month}/${chosenDate.year}'),
        findsOneWidget,
      );
      expect(find.text('12 PM – 3 PM').last, findsOneWidget);
      await reveal(tester, find.text('Schedule pickup'));
      await tester.tap(find.text('Schedule pickup'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await navigate(tester, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('home-continue')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guest trying to book sees sign in prompt and clicking sign in redirects to login screen',
    (tester) async {
      await start(tester, width: 320);
      await navigate(tester, 0);
      await reveal(tester, find.byKey(const Key('pickup-day-1')));
      await tester.tap(find.byKey(const Key('pickup-day-1')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('pickup-window-1')));
      await tester.tap(find.byKey(const Key('pickup-window-1')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('home-continue')));
      await tester.tap(find.byKey(const Key('home-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Sign in to book'), findsOneWidget);
      expect(find.byKey(const Key('booking-sign-in')), findsOneWidget);
      await tester.tap(find.byKey(const Key('booking-sign-in')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('phone')), findsOneWidget);
      expect(find.text('Accept & Send OTP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('prices search and flip both directions at 320 pixel width', (
    tester,
  ) async {
    await start(tester, width: 320);
    expect(tester.takeException(), isNull);
    await navigate(tester, 1);
    await tester.enterText(find.byKey(const Key('price-search')), 'shoe');
    await tester.pumpAndSettle();
    expect(find.text('Canvas Shoes'), findsOneWidget);
    expect(find.text('Wash & Fold'), findsNothing);
    await tester.tap(find.byKey(const Key('price-shoes')));
    await tester.pumpAndSettle();
    expect(find.text('₹425.50'), findsOneWidget);
    await tester.tap(find.byKey(const Key('price-shoes')));
    await tester.pumpAndSettle();
    expect(find.text('₹425.50'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('price-search')),
      'no-matching-item',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching items. Try another search.'), findsOneWidget);
    await navigate(tester, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest retries failed branding and sees the recovered branches', (
    tester,
  ) async {
    var attempts = 0;
    await start(
      tester,
      loadBrand: () async {
        if (attempts++ == 0) throw Exception('offline');
        return brand();
      },
    );
    await navigate(tester, 0);
    await reveal(tester, find.text('Try again'));
    expect(find.text('Brand information could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Brand information could not be loaded.'), findsNothing);
    await navigate(tester, 1);
    expect(find.text('Example branch'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}
