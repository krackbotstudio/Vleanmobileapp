import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance.dart';
import 'auth.dart';
import 'catalog.dart';
import 'customer_api.dart';
import 'booking_screen.dart';
import 'brand_api.dart';
import 'domain.dart';
import 'login_screen.dart';
import 'prices_screen.dart';
import 'pickup_schedule.dart';
import 'service_sphere.dart';
import 'account_data.dart';
import 'account_widgets.dart';
import 'addresses_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'welcome_flow.dart';

void main() => runApp(const VcleanApp(showIntro: true));

typedef DarkToWhiteApp = VcleanApp;

class VcleanApp extends StatefulWidget {
  final Future<BrandInfo> Function()? loadBrand;
  final Future<List<String>> Function()? loadBanners;
  final CatalogLoader? loadCatalogue;
  final CustomerAuth? auth;
  final SessionStore? sessionStore;
  final AccountApi? accountApi;
  final bool enableVideo;
  final bool showIntro;
  const VcleanApp({
    super.key,
    this.loadBrand,
    this.loadBanners,
    this.loadCatalogue,
    this.auth,
    this.sessionStore,
    this.accountApi,
    this.enableVideo = true,
    this.showIntro = false,
  });
  @override
  State<VcleanApp> createState() => _VcleanAppState();
}

class _VcleanAppState extends State<VcleanApp> {
  bool dark = false;
  bool ready = false;
  bool introDone = false;
  bool startAtLogin = true;
  String language = 'en';

  @override
  void initState() {
    super.initState();
    if (!widget.showIntro) {
      ready = true;
      introDone = true;
      return;
    }
    loadIntro();
  }

  Future<void> loadIntro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        language = prefs.getString('vclean_language') ?? 'en';
        introDone = prefs.getBool('vclean_intro_seen') ?? false;
        ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => ready = true);
    }
  }

  Future<void> completeIntro(bool toLogin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vclean_intro_seen', true);
      await prefs.setString('vclean_language', language);
    } catch (_) {
      // The intro can still finish if preferences are unavailable.
    }
    if (!mounted) return;
    setState(() {
      introDone = true;
      startAtLogin = toLogin;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vclean Laundry',
    debugShowCheckedModeBanner: false,
    theme: customerTheme(false),
    darkTheme: customerTheme(true),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(language),
    supportedLocales: const [
      Locale('en'),
      Locale('ta'),
      Locale('ml'),
      Locale('hi'),
    ],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: !ready
        ? const SplashScreen()
        : introDone
        ? CustomerShell(
            dark: dark,
            startAtLogin: startAtLogin,
            toggleTheme: () => setState(() => dark = !dark),
            loadBrand: widget.loadBrand,
            loadBanners: widget.loadBanners,
            loadCatalogue: widget.loadCatalogue,
            auth: widget.auth,
            sessionStore: widget.sessionStore,
            accountApi: widget.accountApi,
            enableVideo: widget.enableVideo,
          )
        : WelcomeFlow(
            language: language,
            onLanguage: (code) => setState(() => language = code),
            onFinished: completeIntro,
          ),
  );
}

class CustomerShell extends StatefulWidget {
  final bool dark, enableVideo, startAtLogin;
  final VoidCallback toggleTheme;
  final Future<BrandInfo> Function()? loadBrand;
  final Future<List<String>> Function()? loadBanners;
  final CatalogLoader? loadCatalogue;
  final CustomerAuth? auth;
  final SessionStore? sessionStore;
  final AccountApi? accountApi;
  const CustomerShell({
    super.key,
    required this.dark,
    this.startAtLogin = true,
    required this.toggleTheme,
    this.loadBrand,
    this.loadBanners,
    this.loadCatalogue,
    this.auth,
    this.sessionStore,
    this.accountApi,
    this.enableVideo = true,
  });
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final bookings = PreviewBookings();
  final client = http.Client();
  DateTime? pickupDate;
  String? pickupWindow;
  late final CustomerAuth auth;
  late final SessionStore sessionStore;
  late final AccountApi accounts;
  CustomerSession? session;
  int sessionGeneration = 0;
  BrandInfo? brand;
  List<String> banners = [];
  late bool login;
  bool loading = true, failed = false;
  int tab = 0;
  List<SavedAddress> addresses = [];
  SavedAddress? selectedAddress;
  bool loadingAddresses = false;
  int activeOrderCount = 0;
  bool loadingOrders = false;

  @override
  void initState() {
    super.initState();
    login = widget.startAtLogin;
    auth = widget.auth ?? AuthApi(CustomerApi(client));
    sessionStore = widget.sessionStore ?? platformSessionStore();
    accounts = widget.accountApi ?? AccountApi(CustomerApi(client));
    restoreSession();
    refreshBrand();
  }

  Future<void> loadAddresses() async {
    final s = session;
    if (s == null) {
      if (mounted) {
        setState(() {
          addresses = [];
          selectedAddress = null;
        });
      }
      return;
    }
    setState(() => loadingAddresses = true);
    try {
      final list = await accounts.addresses(s.token, s.customer.id);
      if (mounted) {
        setState(() {
          addresses = list;
          if (list.isNotEmpty) {
            if (selectedAddress == null ||
                !list.any((a) => a.id == selectedAddress!.id)) {
              selectedAddress = list.firstWhere(
                (a) => a.isDefault,
                orElse: () => list.first,
              );
            }
          } else {
            selectedAddress = null;
          }
        });
      }
    } catch (_) {
      // Ignore network errors on address refresh
    } finally {
      if (mounted) setState(() => loadingAddresses = false);
    }
  }

  Future<void> loadActiveOrders() async {
    final s = session;
    if (s == null) {
      if (mounted) setState(() => activeOrderCount = 0);
      return;
    }
    setState(() => loadingOrders = true);
    try {
      final list = await accounts.orders(s.token);
      if (mounted) {
        setState(() {
          activeOrderCount = list.where((o) => !o.completed).length;
        });
      }
    } catch (_) {
      // Ignore network errors
    } finally {
      if (mounted) setState(() => loadingOrders = false);
    }
  }

  Future<void> restoreSession() async {
    final request = ++sessionGeneration;
    try {
      final token = await sessionStore.read();
      if (token == null || !mounted) return;
      final restored = await auth.restore(token);
      if (mounted && request == sessionGeneration) {
        setState(() {
          session = restored;
          login = false;
        });
        loadAddresses();
        loadActiveOrders();
      }
    } on ApiException catch (e) {
      if ((e.status == 401 || e.status == 403) &&
          request == sessionGeneration) {
        try {
          await sessionStore.clear();
        } catch (_) {
          // Sign-in remains available if secure storage cannot be cleared.
        }
      }
    } catch (_) {
      /* Remain at sign-in when secure storage is unavailable. */
    }
  }

  Future<void> authenticated(CustomerSession verified) async {
    final request = ++sessionGeneration;
    var active = verified;
    try {
      active = await auth.restore(verified.token);
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) rethrow;
    } catch (_) {
      /* The verified customer can continue if profile enrichment is offline. */
    }
    if (!mounted || request != sessionGeneration) return;
    var stored = true;
    try {
      await sessionStore.write(active.token);
    } catch (_) {
      stored = false;
    }
    if (!mounted || request != sessionGeneration) return;
    setState(() {
      session = active;
      login = false;
    });
    loadAddresses();
    loadActiveOrders();
    if (!stored) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signed in for this session. Secure sign-in storage is unavailable.',
          ),
        ),
      );
    }
  }

  Future<void> signOut() async {
    sessionGeneration++;
    try {
      await sessionStore.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-out could not be saved. Please try again.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      session = null;
      login = true;
      tab = 0;
      pickupDate = null;
      pickupWindow = null;
      addresses = [];
      selectedAddress = null;
      activeOrderCount = 0;
      bookings.clear();
    });
  }

  Future<void> refreshBrand() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result =
          await (widget.loadBrand?.call() ?? BrandApi(client).load());
      if (!mounted) return;
      setState(() {
        brand = result;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
    if (!mounted) return;
    try {
      final result =
          await (widget.loadBanners?.call() ?? BrandApi(client).loadBanners());
      if (mounted) setState(() => banners = result);
    } catch (_) {
      /* Keep the reference app's empty banner area. */
    }
  }

  @override
  void dispose() {
    client.close();
    bookings.dispose();
    super.dispose();
  }

  void signIn() => setState(() => login = true);
  void navigate(int index) => setState(() {
    tab = index;
    login = false;
  });

  Future<void> openBooking() async {
    if (pickupDate == null || pickupWindow == null) return;
    if (!pickupDate!.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      setState(() {
        pickupDate = null;
        pickupWindow = null;
      });
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SizedBox(
            height: (media.size.height - media.viewInsets.bottom) * .88,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurface.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Schedule Pickup',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                      NeuIconButton(
                        icon: Icons.close,
                        tooltip: 'Close booking',
                        size: 40,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: BookingScreen(
                    bookings: bookings,
                    branches: brand?.branches ?? const [],
                    initialDate: pickupDate,
                    initialWindow: pickupWindow,
                    initialAddress: selectedAddress,
                    initialAddressId: selectedAddress?.id,
                    session: session,
                    api: accounts,
                    signIn: () {
                      if (sheetContext.mounted &&
                          Navigator.of(sheetContext).canPop()) {
                        Navigator.of(sheetContext).pop();
                      }
                      signIn();
                    },
                    onSaved: () => Navigator.pop(sheetContext, true),
                    onCancel: () => Navigator.pop(sheetContext),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted && saved == true) {
      loadAddresses();
      loadActiveOrders();
      setState(() {
        tab = 2;
        pickupDate = null;
        pickupWindow = null;
      });
    }
  }

  Future<void> showNotificationsSheet() async {
    if (session == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Notifications'),
          content: const Text(
            'Sign in to receive real-time updates and status tracking for your laundry pickups and deliveries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                signIn();
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FutureBuilder<List<Map<String, dynamic>>>(
        future: accounts.notifications(session!.token),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    NeuIconButton(
                      icon: Icons.close,
                      tooltip: 'Close notifications',
                      size: 40,
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No notifications yet. Updates about your pickups and orders will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  ...items.map(
                    (n) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconChip(
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(n['title'] ?? 'Order update'),
                      subtitle: Text(n['body'] ?? n['message'] ?? ''),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: pageBackdrop(widget.dark),
      child: SafeArea(
        bottom: login,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: login
                ? LoginScreen(
                    auth: auth,
                    onAuthenticated: authenticated,
                    brand: brand,
                    enableVideo: widget.enableVideo,
                    onSkip: () => navigate(tab),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 18, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: neuRaised(
                                widget.dark,
                                radius: 16,
                                depth: 4,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  BrandColors.logo,
                                  width: 34,
                                  height: 34,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?.customer.name?.trim().isNotEmpty ==
                                            true
                                        ? 'Hello ${session!.customer.name!.trim()}'
                                        : 'Hello',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 22),
                                  ),
                                  Text(
                                    'Laundry, done for you',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedText(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            NeuIconButton(
                              icon: widget.dark
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              tooltip: 'Toggle Dark/Light Mode',
                              onPressed: widget.toggleTheme,
                              accent: true,
                            ),
                            const SizedBox(width: 10),
                            NeuIconButton(
                              icon: Icons.notifications_none,
                              tooltip: 'Notifications',
                              onPressed: showNotificationsSheet,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: switch (tab) {
                          0 => home(),
                          1 => PricesScreen(
                            branches: brand?.branches ?? const [],
                            refreshBranches: refreshBrand,
                            loadCatalogue:
                                widget.loadCatalogue ??
                                (id) => CatalogApi(
                                  CustomerApi(client),
                                ).load(id, brand?.branches ?? const []),
                          ),
                          2 => orders(),
                          _ => profile(),
                        },
                      ),
                      navigation(),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  Widget navigation() {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: neuRaised(widget.dark, radius: 26, depth: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final item in [
              (0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              (1, Icons.list_alt_rounded, Icons.list_alt_outlined, 'Prices'),
              (
                2,
                Icons.shopping_bag_rounded,
                Icons.shopping_bag_outlined,
                'Orders',
              ),
              (
                3,
                Icons.person_rounded,
                Icons.person_outline_rounded,
                'Profile',
              ),
            ])
              Flexible(
                flex: tab == item.$1 ? 2 : 1,
                child: Semantics(
                  button: true,
                  selected: tab == item.$1,
                  label: item.$4,
                  child: InkWell(
                    key: Key('nav-${item.$1}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => navigate(item.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      height: 48,
                      padding: EdgeInsets.symmetric(
                        horizontal: tab == item.$1 ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: tab == item.$1 ? brandGradient : null,
                        boxShadow: tab == item.$1
                            ? [
                                BoxShadow(
                                  color: BrandColors.purple.withValues(
                                    alpha: .38,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab == item.$1 ? item.$2 : item.$3,
                            size: 22,
                            color: tab == item.$1
                                ? Colors.white
                                : fg.withValues(alpha: .5),
                          ),
                          if (tab == item.$1) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.$4,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget home() => RefreshIndicator(
    onRefresh: () async {
      await refreshBrand();
      await loadAddresses();
      await loadActiveOrders();
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AspectRatio(
          aspectRatio: 1 / .7,
          child: ServiceSphere(banners: banners),
        ),
        if (session != null && activeOrderCount > 0) activeOrdersBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              addressSection(),
              const SizedBox(height: 18),
              PickupSchedule(
                date: pickupDate,
                window: pickupWindow,
                onDateChanged: (value) => setState(() {
                  if (!DateUtils.isSameDay(pickupDate, value)) {
                    pickupWindow = null;
                  }
                  pickupDate = value;
                }),
                onWindowChanged: (value) =>
                    setState(() => pickupWindow = value),
                onContinue: openBooking,
              ),
              if (failed) ...[
                const SizedBox(height: 14),
                AccountError(
                  'Brand information could not be loaded.',
                  refreshBrand,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget activeOrdersBanner() {
    final dark = widget.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: neuRaised(dark, radius: 24, depth: 6),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('home-active-orders'),
            onTap: () => navigate(2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconChip(
                        Icon(
                          Icons.local_laundry_service_rounded,
                          color: primary,
                          size: 22,
                        ),
                        size: 46,
                      ),
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: brandRaised(shape: BoxShape.circle),
                          child: Text(
                            '$activeOrderCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeOrderCount == 1
                              ? '1 Active Order'
                              : '$activeOrderCount Active Orders',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to track your orders',
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: brandRaised(radius: 20),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget homeCard({Key? key, VoidCallback? onTap, required Widget child}) =>
      Container(
        decoration: neuRaised(widget.dark, radius: 24, depth: 6),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: child,
            ),
          ),
        ),
      );

  Widget addressSection() {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = mutedText(context);
    Widget lines(String title, String subtitle, {Widget? badge}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            ?badge,
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: muted, height: 1.35),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Pickup address',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
            if (session != null && addresses.isNotEmpty) ...[
              if (addresses.length > 1)
                TextButton(
                  key: const Key('home-change-address'),
                  onPressed: showAddressSelector,
                  child: const Text('Change'),
                ),
              TextButton.icon(
                key: const Key('home-manage-address'),
                onPressed: openManageAddresses,
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('Manage'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (session == null)
          homeCard(
            onTap: signIn,
            child: Row(
              children: [
                IconChip(
                  Icon(Icons.person_outline_rounded, color: primary, size: 21),
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: lines(
                    'Sign in to select address',
                    'Choose from your saved addresses or add a new one',
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: muted),
              ],
            ),
          )
        else if (loadingAddresses)
          homeCard(
            child: const SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (selectedAddress != null)
          homeCard(
            key: const Key('home-address-card'),
            onTap: showAddressSelector,
            child: Row(
              children: [
                IconChip(
                  Icon(
                    selectedAddress!
                            .text('label')
                            .toLowerCase()
                            .contains('office')
                        ? Icons.apartment_outlined
                        : Icons.home_outlined,
                    color: primary,
                    size: 21,
                  ),
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: lines(
                    selectedAddress!.text('label').isNotEmpty
                        ? selectedAddress!.text('label')
                        : 'Pickup address',
                    '${selectedAddress!.text('addressLine')}, ${selectedAddress!.text('pincode')}',
                    badge: selectedAddress!.isDefault
                        ? Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: brandRaised(radius: 8),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: .5,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                Icon(Icons.unfold_more_rounded, size: 20, color: muted),
              ],
            ),
          )
        else
          homeCard(
            onTap: openManageAddresses,
            child: Row(
              children: [
                IconChip(
                  Icon(
                    Icons.add_location_alt_outlined,
                    color: primary,
                    size: 21,
                  ),
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: lines(
                    'Add a pickup address',
                    'Save where we should collect your laundry',
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: muted),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> showAddressSelector() async {
    final chosen = await showModalBottomSheet<SavedAddress>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Pickup Address',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              for (final a in addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NeuOption(
                    selected: selectedAddress?.id == a.id,
                    onTap: () => Navigator.pop(ctx, a),
                    child: Row(
                      children: [
                        Icon(
                          selectedAddress?.id == a.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.text('label').isNotEmpty
                                    ? a.text('label')
                                    : 'Address',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Opacity(
                                opacity: .75,
                                child: Text(
                                  '${a.text('addressLine')}, ${a.text('pincode')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('selector-add-address'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await addNewAddress();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add address'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('selector-manage-address'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await openManageAddresses();
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Manage'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => selectedAddress = chosen);
    }
  }

  Future<void> openManageAddresses() async {
    final s = session;
    if (s == null) {
      signIn();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddressesScreen(api: accounts, session: s),
      ),
    );
    await loadAddresses();
  }

  Future<void> addNewAddress() async {
    final s = session;
    if (s == null) {
      signIn();
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddressEditor(api: accounts, session: s),
      ),
    );
    if (saved == true && mounted) {
      await loadAddresses();
    }
  }

  Widget orders() => OrdersScreen(
    key: ValueKey('orders-${session?.customer.id}-$sessionGeneration'),
    session: session,
    api: accounts,
    signIn: signIn,
    previews: bookings,
  );

  Widget profile() => ProfileScreen(
    key: ValueKey('profile-${session?.customer.id}-$sessionGeneration'),
    session: session,
    brand: brand,
    api: accounts,
    signIn: signIn,
    signOut: signOut,
    openOrders: () => navigate(2),
    onProfileChanged: (updated) {
      if (!mounted || session?.customer.id != updated.id) return;
      setState(() => session = CustomerSession(session!.token, updated));
    },
  );
}

String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String monthLabel(DateTime date) => const [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][date.month - 1];

class ServicesHorizontalBar extends StatelessWidget {
  final ValueChanged<String>? onServiceSelected;
  const ServicesHorizontalBar({super.key, this.onServiceSelected});

  static const _items = [
    ('daily', 'Wash & Fold', 'assets/service-icons/wash-and-fold.png'),
    ('pressed', 'Wash & Iron', 'assets/service-icons/wash-and-iron.png'),
    ('delicates', 'Dry Clean', 'assets/service-icons/dry-cleaning.png'),
    ('shoes', 'Shoe Cleaning', 'assets/service-icons/shoe-cleaning.png'),
    ('steam', 'Steam Iron', 'assets/service-icons/steam-iron.png'),
    ('linen', 'Home Linen', 'assets/service-icons/home-linen.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          child: Text(
            'OUR SERVICES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: dark ? 0.6 : 0.5),
            ),
          ),
        ),
        SizedBox(
          height: 122,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _items[index];
              return InkWell(
                onTap: () => onServiceSelected?.call(item.$1),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: neuRaised(dark, radius: 18, depth: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        item.$3,
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
