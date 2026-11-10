import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
import 'addresses_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

void main() => runApp(const VcleanApp());

typedef DarkToWhiteApp = VcleanApp;

class VcleanApp extends StatefulWidget {
  final Future<BrandInfo> Function()? loadBrand;
  final Future<List<String>> Function()? loadBanners;
  final CatalogLoader? loadCatalogue;
  final CustomerAuth? auth;
  final SessionStore? sessionStore;
  final AccountApi? accountApi;
  final bool enableVideo;
  const VcleanApp({
    super.key,
    this.loadBrand,
    this.loadBanners,
    this.loadCatalogue,
    this.auth,
    this.sessionStore,
    this.accountApi,
    this.enableVideo = true,
  });
  @override
  State<VcleanApp> createState() => _VcleanAppState();
}

class _VcleanAppState extends State<VcleanApp> {
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vclean Laundry',
    debugShowCheckedModeBanner: false,
    theme: customerTheme(false),
    darkTheme: customerTheme(true),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: CustomerShell(
      dark: dark,
      toggleTheme: () => setState(() => dark = !dark),
      loadBrand: widget.loadBrand,
      loadBanners: widget.loadBanners,
      loadCatalogue: widget.loadCatalogue,
      auth: widget.auth,
      sessionStore: widget.sessionStore,
      accountApi: widget.accountApi,
      enableVideo: widget.enableVideo,
    ),
  );
}

class CustomerShell extends StatefulWidget {
  final bool dark, enableVideo;
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
  bool login = true, loading = true, failed = false;
  int tab = 0;
  List<SavedAddress> addresses = [];
  SavedAddress? selectedAddress;
  bool loadingAddresses = false;
  int activeOrderCount = 0;
  bool loadingOrders = false;

  @override
  void initState() {
    super.initState();
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
      backgroundColor: widget.dark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                      const Expanded(
                        child: Text(
                          'Schedule Pickup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close booking',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
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
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
                  ...items.map((n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.notifications_active_outlined, size: 18),
                    ),
                    title: Text(n['title'] ?? 'Order update'),
                    subtitle: Text(n['body'] ?? n['message'] ?? ''),
                  )),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.dark
              ? const [Color(0xFF12131A), Color(0xFF07070A), Color(0xFF0E1016)]
              : const [Color(0xFFECEEF5), Color(0xFFF5F5F7), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: login
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: LoginScreen(
                          auth: auth,
                          onAuthenticated: authenticated,
                          brand: brand,
                          enableVideo: widget.enableVideo,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: navigation(),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                session?.customer.name?.trim().isNotEmpty ==
                                        true
                                    ? 'Hello ${session!.customer.name!.trim()}'
                                    : 'Hello',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .2,
                                ),
                              ),
                            ),
                            headerButton(
                              widget.dark ? Icons.light_mode : Icons.dark_mode,
                              'Toggle Dark/Light Mode',
                              widget.toggleTheme,
                            ),
                            const SizedBox(width: 8),
                            headerButton(
                              Icons.notifications_none,
                              'Notifications',
                              showNotificationsSheet,
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

  Widget headerButton(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
        tooltip: tooltip,
        onPressed: action,
        icon: Icon(icon, size: 24),
        style: IconButton.styleFrom(
          backgroundColor: widget.dark
              ? Colors.white.withValues(alpha: .1)
              : Colors.black.withValues(alpha: .04),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          fixedSize: const Size(42, 42),
        ),
      );

  Widget navigation() => LayoutBuilder(
    builder: (context, constraints) {
      final navWidth = math.min(300.0, (constraints.maxWidth - 32) * .8);
      final circle = math.min(58.0, (navWidth - 12) / 4);
      final fg = Theme.of(context).colorScheme.onSurface;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Center(
          child: Container(
            width: navWidth,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.dark
                        ? const Color(0x8C121216)
                        : const Color(0x8CFFFFFF),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(
                      color: widget.dark
                          ? const Color(0x47FFFFFF)
                          : const Color(0xBFFFFFFF),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      for (final item in [
                        (0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                        (1, Icons.list_alt_rounded, Icons.list_alt_outlined, 'Prices'),
                        (2, Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, 'Orders'),
                        (3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
                      ])
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: tab == item.$1,
                            label: item.$4,
                            child: InkWell(
                              key: Key('nav-${item.$1}'),
                              onTap: () => navigate(item.$1),
                              child: Center(
                                child: Container(
                                  width: circle,
                                  height: circle,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tab == item.$1
                                        ? fg
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        tab == item.$1 ? item.$2 : item.$3,
                                        size: 22,
                                        color: tab == item.$1
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : fg.withValues(alpha: .55),
                                      ),
                                      Text(
                                        item.$4,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: tab == item.$1
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: tab == item.$1
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary
                                              : fg.withValues(alpha: .55),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget home() => RefreshIndicator(
    onRefresh: () async {
      await refreshBrand();
      await loadAddresses();
      await loadActiveOrders();
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const AspectRatio(aspectRatio: 1 / .58, child: ServiceSphere()),
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
                const Text('Brand information could not be loaded.'),
                TextButton.icon(
                  onPressed: refreshBrand,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-active-orders'),
          onTap: () => navigate(2),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF1A1B2E), const Color(0xFF1E2040)]
                    : [const Color(0xFFEEF0FF), const Color(0xFFE8ECFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primary.withValues(alpha: dark ? 0.3 : 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: dark ? 0.12 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.local_laundry_service_rounded,
                          color: primary,
                          size: 22,
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dark
                                    ? const Color(0xFF1A1B2E)
                                    : const Color(0xFFEEF0FF),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$activeOrderCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to track your orders',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: primary),
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

  Widget addressSection() {
    final dark = widget.dark;
    final fg = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Pickup address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
        const SizedBox(height: 8),
        if (session == null)
          InkWell(
            onTap: signIn,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF161722) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sign in to select address',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose from your saved addresses or add a new one',
                          style: TextStyle(
                            fontSize: 12,
                            color: fg.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          )
        else if (loadingAddresses)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF161722) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (selectedAddress != null)
          InkWell(
            key: const Key('home-address-card'),
            onTap: showAddressSelector,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF161722) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selectedAddress!.text('label').toLowerCase().contains('office')
                          ? Icons.apartment_outlined
                          : Icons.home_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedAddress!.text('label').isNotEmpty
                                  ? selectedAddress!.text('label')
                                  : 'Pickup address',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (selectedAddress!.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedAddress!.text('addressLine')}, ${selectedAddress!.text('pincode')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: fg.withValues(alpha: 0.65),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 20,
                    color: fg.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          )
        else
          InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddressesScreen(
                    api: accounts,
                    session: session!,
                  ),
                ),
              );
              loadAddresses();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF161722) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_location_alt_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add a pickup address',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> showAddressSelector() async {
    final chosen = await showModalBottomSheet<SavedAddress>(
      context: context,
      backgroundColor: widget.dark ? const Color(0xFF161722) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Pickup Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              for (final a in addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, a),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedAddress?.id == a.id
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.12),
                          width: selectedAddress?.id == a.id ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedAddress?.id == a.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selectedAddress?.id == a.id
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.text('label').isNotEmpty ? a.text('label') : 'Address',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${a.text('addressLine')}, ${a.text('pincode')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
        builder: (_) => AddressesScreen(
          api: accounts,
          session: s,
        ),
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
        builder: (_) => AddressEditor(
          api: accounts,
          session: s,
        ),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: dark ? 0.6 : 0.5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF161722)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
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

