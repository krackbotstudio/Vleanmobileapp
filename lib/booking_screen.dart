import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_data.dart';
import 'account_widgets.dart';
import 'addresses_screen.dart';
import 'appearance.dart';
import 'auth.dart';
import 'brand_api.dart';
import 'domain.dart';

class BookingScreen extends StatefulWidget {
  final PreviewBookings bookings;
  final List<Branch> branches;
  final Set<String> initialServices;
  final DateTime? initialDate;
  final String? initialWindow;
  final String? initialAddressId;
  final SavedAddress? initialAddress;
  final CustomerSession? session;
  final AccountApi? api;
  final VoidCallback? signIn;
  final VoidCallback onSaved, onCancel;

  const BookingScreen({
    super.key,
    required this.bookings,
    required this.onSaved,
    required this.onCancel,
    this.branches = const [],
    this.initialServices = const {},
    this.initialDate,
    this.initialWindow,
    this.initialAddressId,
    this.initialAddress,
    this.session,
    this.api,
    this.signIn,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int step = 0;
  final address = TextEditingController(), postal = TextEditingController();
  final form = GlobalKey<FormState>();
  final requestId = UniqueKey().toString();
  late DateTime day;
  String? branchId;
  String window = sampleWindows.first;
  bool submitted = false;
  bool loadingAddresses = false;
  List<SavedAddress> savedAddresses = [];
  String? selectedAddressId;
  String? submitError;

  bool get scheduledFromHome =>
      widget.initialDate != null && widget.initialWindow != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    day = widget.initialDate ?? DateTime(now.year, now.month, now.day + 1);
    window = widget.initialWindow ?? sampleWindows.first;

    if (widget.initialAddress != null) {
      final init = widget.initialAddress!;
      selectedAddressId = init.id;
      address.text = init.text('addressLine');
      postal.text = init.text('pincode');
      if (scheduledFromHome) {
        if (widget.branches.length == 1) {
          branchId = widget.branches.first.id;
          step = 4;
        } else if (widget.branches.length > 1) {
          step = 1;
        } else {
          step = 4;
        }
      }
    } else if (widget.branches.length == 1) {
      branchId = widget.branches.first.id;
    }

    if (widget.session != null && widget.api != null) {
      loadAddresses();
    }
  }

  Future<void> loadAddresses([String? preferredId]) async {
    final session = widget.session;
    final api = widget.api;
    if (session == null || api == null) return;
    setState(() => loadingAddresses = true);
    try {
      final list = await api.addresses(session.token, session.customer.id);
      if (mounted) {
        setState(() {
          savedAddresses = list;
          if (list.isNotEmpty) {
            final targetId =
                preferredId ??
                selectedAddressId ??
                widget.initialAddress?.id ??
                widget.initialAddressId;
            selectedAddressId =
                targetId != null && list.any((a) => a.id == targetId)
                ? targetId
                : list.first.id;
            final chosen = list.firstWhere(
              (a) => a.id == selectedAddressId,
              orElse: () => list.first,
            );
            if (address.text.isEmpty || selectedAddressId == chosen.id) {
              address.text = chosen.text('addressLine');
              postal.text = chosen.text('pincode');
            }
          }
        });
      }
    } catch (_) {
      // Ignore network failures for address list in booking screen
    } finally {
      if (mounted) setState(() => loadingAddresses = false);
    }
  }

  @override
  void dispose() {
    address.dispose();
    postal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey(step),
    padding: const EdgeInsets.all(24),
    children: [
      if (submitError != null)
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: neuRaised(
            Theme.of(context).brightness == Brightness.dark,
            radius: 22,
            depth: 5,
          ),
          child: Row(
            children: [
              IconChip(
                Icon(
                  Icons.error_outline_rounded,
                  size: 19,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  submitError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      switch (step) {
        0 => addressStep(),
        1 => branchStep(),
        2 => dateStep(),
        3 => timeStep(),
        _ => reviewStep(),
      },
      const SizedBox(height: 18),
      if (step > 0)
        OutlinedButton(
          onPressed: () => setState(
            () => step = step == 4 && scheduledFromHome
                ? (widget.initialAddress != null
                      ? (widget.branches.length > 1 ? 1 : 0)
                      : 1)
                : step - 1,
          ),
          child: const Text('Back'),
        ),
      const SizedBox(height: 6),
      TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
    ],
  );

  Widget addressStep() {
    // If not signed in, show sign-in prompt instead of address input
    if (widget.session == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            'Sign in to book',
            'Please sign in to schedule a pickup.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: neuRaised(
              Theme.of(context).brightness == Brightness.dark,
              radius: 30,
              depth: 10,
            ),
            child: Column(
              children: [
                IconChip(
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 26,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You need to be signed in to schedule a laundry pickup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('booking-sign-in'),
                  onPressed: () {
                    widget.onCancel();
                    widget.signIn?.call();
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (savedAddresses.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            'Pickup address',
            'Choose a saved pickup address or enter a new one.',
          ),
          ...savedAddresses.map((a) {
            final isChosen = selectedAddressId == a.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuOption(
                selected: isChosen,
                onTap: () => setState(() {
                  selectedAddressId = a.id;
                  address.text = a.text('addressLine');
                  postal.text = a.text('pincode');
                }),
                child: Row(
                  children: [
                    Icon(
                      isChosen
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.text('label').isEmpty
                                ? 'Address'
                                : a.text('label'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Opacity(
                            opacity: .75,
                            child: Text(
                              '${a.text('addressLine')}, ${a.text('pincode')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('booking-add-address'),
                  onPressed: () async {
                    if (widget.session != null && widget.api != null) {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AddressEditor(
                            api: widget.api!,
                            session: widget.session!,
                          ),
                        ),
                      );
                      if (saved == true && mounted) {
                        await loadAddresses();
                      }
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add address'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('booking-manage-addresses'),
                  onPressed: () async {
                    if (widget.session != null && widget.api != null) {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AddressesScreen(
                            api: widget.api!,
                            session: widget.session!,
                          ),
                        ),
                      );
                      await loadAddresses();
                    }
                  },
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => step = 1),
            child: const Text('Continue'),
          ),
        ],
      );
    }

    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            'Pickup address',
            'Enter your pickup and delivery address.',
          ),
          if (widget.session != null && widget.api != null) ...[
            OutlinedButton.icon(
              key: const Key('booking-add-saved-address'),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddressEditor(
                      api: widget.api!,
                      session: widget.session!,
                    ),
                  ),
                );
                if (saved == true && mounted) {
                  await loadAddresses();
                }
              },
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add & save a new address'),
            ),
            const SizedBox(height: 16),
          ],
          NeuField(
            child: TextFormField(
              key: const Key('address'),
              controller: address,
              minLines: 2,
              maxLines: 3,
              decoration: neuBareField.copyWith(
                labelText: 'Address',
                hintText: 'Flat, building, street and area',
              ),
              validator: (value) => (value ?? '').trim().length < 10
                  ? 'Enter a complete pickup address.'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          NeuField(
            child: TextFormField(
              key: const Key('postal'),
              controller: postal,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: neuBareField.copyWith(labelText: 'Pincode'),
              validator: (value) =>
                  RegExp(r'^[1-9]\d{5}$').hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter a valid six-digit postal code.',
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) setState(() => step = 1);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget branchStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Select branch',
        'Select the Vclean branch serving your pickup.',
      ),
      if (widget.branches.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Finding available branch for your location…'),
        ),
      ...widget.branches.map(
        (branch) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeuOption(
            selected: branch.id == branchId,
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            onTap: () => setState(() {
              branchId = branch.id;
              step = scheduledFromHome ? 4 : 2;
            }),
            child: Row(
              children: [
                IconChip(
                  Icon(
                    Icons.storefront_outlined,
                    size: 19,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    branch.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
      if (widget.branches.isEmpty)
        FilledButton(
          onPressed: () => setState(() => step = scheduledFromHome ? 4 : 2),
          child: const Text('Continue'),
        ),
    ],
  );

  Widget dateStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Pickup date',
        'Choose a collection date within the next two weeks.',
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 22),
        decoration: neuRaised(
          Theme.of(context).brightness == Brightness.dark,
          radius: 26,
          depth: 7,
        ),
        child: CalendarDatePicker(
          initialDate: day,
          firstDate: DateTime.now().add(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 14)),
          onDateChanged: (value) => setState(() => day = value),
        ),
      ),
      FilledButton(
        onPressed: () => setState(() => step = 3),
        child: const Text('Continue → Time slot'),
      ),
    ],
  );

  Widget timeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Pickup time',
        'Select a convenient time window for collection.',
      ),
      ...sampleWindows.map(
        (slot) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeuOption(
            selected: window == slot,
            onTap: () => setState(() => window = slot),
            child: Row(
              children: [
                Icon(
                  window == slot
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                const SizedBox(width: 12),
                Text(slot, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: () => setState(() => step = 4),
        child: const Text('Continue → Review'),
      ),
    ],
  );

  Widget reviewStep() {
    final signedIn = widget.session != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          'Confirm pickup',
          'Review the details of your scheduled pickup.',
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
          decoration: neuRaised(
            Theme.of(context).brightness == Brightness.dark,
            radius: 26,
            depth: 7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detail(
                'Address',
                '${address.text.trim()}\n${postal.text.trim()}',
              ),
              if (branchId != null)
                _detail(
                  'Branch',
                  widget.branches
                      .firstWhere((branch) => branch.id == branchId)
                      .name,
                ),
              _detail('Pickup date', '${day.day}/${day.month}/${day.year}'),
              _detail('Time slot', window),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => step = 0),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Change address'),
            ),
            TextButton.icon(
              onPressed: () => setState(() => step = 2),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Change date or time'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!signedIn && widget.signIn != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: neuRaised(
                Theme.of(context).brightness == Brightness.dark,
                radius: 22,
                depth: 5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sign in to track this pickup directly in your account.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: widget.signIn,
                    child: const Text('Sign in / Register'),
                  ),
                ],
              ),
            ),
          ),
        FilledButton(
          onPressed: submitted
              ? null
              : () async {
                  final pickup = PickupDraft(
                    service: sampleServices.first,
                    additionalServices: const [],
                    address: address.text.trim(),
                    postalCode: postal.text.trim(),
                    window: window,
                    date: day,
                  );
                  final error = pickup.validate(DateTime.now());
                  if (error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }

                  setState(() {
                    submitted = true;
                    submitError = null;
                  });

                  // If logged in, create real live order via backend API
                  if (widget.session != null && widget.api != null) {
                    try {
                      final token = widget.session!.token;
                      var addrId = selectedAddressId;
                      if (addrId == null || addrId.isEmpty) {
                        await widget.api!.saveAddress(token, {
                          'label': 'Home',
                          'addressLine': address.text.trim(),
                          'pincode': postal.text.trim(),
                        });
                        final list = await widget.api!.addresses(
                          token,
                          widget.session!.customer.id,
                        );
                        addrId = list.isNotEmpty ? list.first.id : 'default';
                      }

                      final dateStr =
                          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                      await widget.api!.createOrder(
                        token,
                        addressId: addrId,
                        pickupDate: dateStr,
                        timeWindow: window,
                        selectedServices: const [],
                        branchId: branchId,
                      );
                      widget.onSaved();
                      return;
                    } catch (e) {
                      setState(() {
                        submitted = false;
                        submitError = failureMessage(e);
                      });
                      return;
                    }
                  }

                  // Guest / fallback booking
                  widget.bookings.create(pickup, requestId, DateTime.now());
                  widget.onSaved();
                },
          child: Text(
            submitted
                ? 'Scheduling…'
                : signedIn
                ? 'Schedule pickup'
                : 'Save preview booking',
          ),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
