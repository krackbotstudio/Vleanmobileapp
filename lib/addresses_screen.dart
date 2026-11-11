import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'account_data.dart';
import 'account_widgets.dart';
import 'appearance.dart';
import 'auth.dart';
import 'brand_api.dart';
import 'customer_api.dart';
import 'location_provider.dart';

class AddressesScreen extends StatefulWidget {
  final AccountApi api;
  final CustomerSession session;
  const AddressesScreen({super.key, required this.api, required this.session});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<SavedAddress> addresses = [];
  Set<String> locked = {};
  bool loading = true, deleting = false;
  String? error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        widget.api.addresses(widget.session.token, widget.session.customer.id),
        widget.api.orders(widget.session.token),
      ]);
      if (!mounted) return;
      setState(() {
        addresses = result[0] as List<SavedAddress>;
        locked = (result[1] as List<CustomerOrder>)
            .where((o) => !o.completed)
            .map((o) => o.text('addressId'))
            .where((id) => id.isNotEmpty)
            .toSet();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = failureMessage(e);
          addresses = [];
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([SavedAddress? address]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddressEditor(
          api: widget.api,
          session: widget.session,
          address: address,
        ),
      ),
    );
    if (mounted && saved == true) refresh();
  }

  Future<void> remove(SavedAddress address) async {
    if (deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(
          'Remove ${address.text('label')} from your saved pickup locations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await widget.api.deleteAddress(widget.session.token, address.id);
      if (mounted) await refresh();
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  Widget pill(String text, {bool accent = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: accent
        ? brandRaised(radius: 10)
        : neuPressed(
            Theme.of(context).brightness == Brightness.dark,
            radius: 10,
          ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: accent ? Colors.white : mutedText(context),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => NeuPage(
    title: 'My Addresses',
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Add and manage your pickup locations.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: mutedText(context),
            ),
          ),
          const SizedBox(height: 20),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            AccountError(error!, refresh)
          else if (addresses.isEmpty)
            AccountPanel(
              child: Row(
                children: [
                  IconChip(
                    Icon(
                      Icons.location_off_outlined,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('No addresses yet. Add one below.'),
                  ),
                ],
              ),
            )
          else
            ...addresses.map(
              (address) => AccountPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconChip(
                          Icon(
                            address
                                    .text('label')
                                    .toLowerCase()
                                    .contains('office')
                                ? Icons.apartment_outlined
                                : Icons.home_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          size: 42,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    address.text('label'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (address.isDefault)
                                    pill('Default', accent: true),
                                  if (locked.contains(address.id))
                                    pill('Active order'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                address.text('addressLine'),
                                style: const TextStyle(height: 1.4),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pincode: ${address.text('pincode')}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (locked.contains(address.id))
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Edit and delete are available after active orders here are completed or cancelled.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              key: Key('edit-address-${address.id}'),
                              onPressed: deleting ? null : () => edit(address),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              key: Key('delete-address-${address.id}'),
                              onPressed: deleting
                                  ? null
                                  : () => remove(address),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: loading || deleting ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add address'),
          ),
        ],
      ),
    ),
  );
}

class AddressEditor extends StatefulWidget {
  final AccountApi api;
  final CustomerSession session;
  final SavedAddress? address;
  const AddressEditor({
    super.key,
    required this.api,
    required this.session,
    this.address,
  });
  @override
  State<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<AddressEditor> {
  final form = GlobalKey<FormState>();
  final label = TextEditingController(),
      house = TextEditingController(),
      street = TextEditingController(),
      city = TextEditingController(),
      pincode = TextEditingController(),
      maps = TextEditingController();
  List<Branch> branches = [];
  bool isDefault = false,
      busy = false,
      checking = false,
      checked = false,
      requested = false,
      locating = false;
  String? error, serviceError, gpsError;
  Timer? debounce;
  int generation = 0;

  Future<void> useCurrentLocation() async {
    if (locating || busy) return;
    setState(() {
      locating = true;
      gpsError = null;
    });
    try {
      final result = await fetchCurrentLocation();
      if (!mounted) return;
      setState(() {
        maps.text = result.googleMapsUrl;
        if (result.city != null && result.city!.isNotEmpty) {
          city.text = result.city!;
        }
        if (result.streetArea != null &&
            result.streetArea!.isNotEmpty &&
            street.text.isEmpty) {
          street.text = result.streetArea!;
        }
        if (result.pincode != null && result.pincode!.isNotEmpty) {
          pincode.text = result.pincode!;
          pincodeChanged(result.pincode!);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          gpsError =
              'Could not fetch current GPS location. Please allow location access or enter manually.';
        });
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.address;
    if (initial != null) {
      label.text = initial.text('label');
      house.text = initial.text('houseNo');
      street.text = initial.text('streetArea');
      city.text = initial.text('city');
      if (house.text.isEmpty && street.text.isEmpty && city.text.isEmpty) {
        final parts = initial
            .text('addressLine')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        house.text = parts.isEmpty ? '' : parts.first;
        if (parts.length > 2) {
          street.text = parts.sublist(1, parts.length - 1).join(', ');
          city.text = parts.last;
        } else if (parts.length == 2) {
          street.text = parts.last;
        }
      }
      pincode.text = initial.text('pincode');
      maps.text = initial.text('googleMapUrl');
      isDefault = initial.isDefault;
      check();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    for (final c in [label, house, street, city, pincode, maps]) {
      c.dispose();
    }
    super.dispose();
  }

  void pincodeChanged(String value) {
    debounce?.cancel();
    generation++;
    setState(() {
      branches = [];
      checked = false;
      checking = false;
      serviceError = null;
      requested = false;
    });
    if (value.length == 6) {
      debounce = Timer(const Duration(milliseconds: 450), check);
    }
  }

  Future<void> check() async {
    final request = ++generation;
    final value = pincode.text.trim();
    setState(() {
      checking = true;
      serviceError = null;
      checked = false;
      branches = [];
    });
    try {
      final result = await widget.api.servingBranches(value);
      if (mounted && request == generation && pincode.text.trim() == value) {
        setState(() {
          branches = result;
          checked = true;
        });
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => serviceError = failureMessage(e));
      }
    } finally {
      if (mounted && request == generation) setState(() => checking = false);
    }
  }

  String get line => [
    house.text.trim(),
    street.text.trim(),
    city.text.trim(),
  ].where((s) => s.isNotEmpty).join(', ');
  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final serving = await widget.api.servingBranches(pincode.text.trim());
      if (serving.isEmpty) {
        throw const ApiException(
          'This pincode is not currently served. You can request service for your area below.',
        );
      }
      await widget.api.saveAddress(widget.session.token, {
        'label': label.text.trim(),
        'addressLine': line,
        'houseNo': house.text.trim(),
        'streetArea': street.text.trim(),
        'city': city.text.trim(),
        'pincode': pincode.text.trim(),
        'isDefault': isDefault,
        'googleMapUrl': maps.text.trim().isEmpty ? null : maps.text.trim(),
      }, id: widget.address?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestArea() async {
    if (busy || requested || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.requestArea(
        widget.session.customer,
        pincode.text.trim(),
        line,
      );
      if (mounted) setState(() => requested = true);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(String key, String title, TextEditingController controller) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: NeuField(
          child: TextFormField(
            key: Key(key),
            controller: controller,
            enabled: !busy,
            maxLength: 180,
            decoration: neuBareField.copyWith(
              labelText: title,
              counterText: '',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter $title.' : null,
          ),
        ),
      );
  Widget sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 12, left: 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: NeuPage(
      title: widget.address == null ? 'Add address' : 'Edit address',
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Add address details and check if we serve your area.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: mutedText(context),
              ),
            ),
            const SizedBox(height: 20),
            input('address-label', 'Label (e.g. Home, Office)', label),
            const SizedBox(height: 4),
            sectionHeader('Locate via GPS'),
            OutlinedButton.icon(
              key: const Key('use-gps-button'),
              onPressed: locating || busy ? null : useCurrentLocation,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 20),
              label: Text(
                locating ? 'Locating...' : 'Use Current Location (GPS)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (maps.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Link: ${maps.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ),
            if (gpsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  gpsError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            sectionHeader('Address details'),
            input('address-house', 'House / Flat no.', house),
            input('address-street', 'Street & area', street),
            input('address-city', 'City', city),
            NeuField(
              child: TextFormField(
                key: const Key('address-pincode'),
                controller: pincode,
                enabled: !busy,
                onChanged: pincodeChanged,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: neuBareField.copyWith(
                  labelText: 'Pincode (6 digits)',
                ),
                validator: (v) => RegExp(r'^[1-9]\d{5}$').hasMatch(v ?? '')
                    ? null
                    : 'Enter a valid six-digit pincode.',
              ),
            ),
            const SizedBox(height: 6),
            if (checking)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Checking service areas...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (serviceError != null)
              AccountError(serviceError!, check)
            else if (checked)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  branches.isEmpty
                      ? 'This area is not currently served.'
                      : 'Served by ${branches.map((b) => b.name).join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: branches.isEmpty
                        ? const Color(0xFFD97706)
                        : const Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            NeuField(
              child: TextFormField(
                key: const Key('address-maps-url'),
                controller: maps,
                enabled: !busy,
                keyboardType: TextInputType.url,
                decoration: neuBareField.copyWith(
                  labelText: 'Google Maps link (optional)',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return null;
                  }
                  final uri = Uri.tryParse(value);
                  return uri != null &&
                          uri.scheme == 'https' &&
                          uri.host.isNotEmpty
                      ? null
                      : 'Enter a valid HTTPS Maps link.';
                },
              ),
            ),
            const SizedBox(height: 16),
            NeuField(
              margin: const EdgeInsets.only(bottom: 16),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Set as default address',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                value: isDefault,
                onChanged: busy
                    ? null
                    : (value) => setState(() => isDefault = value),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy || checking || branches.isEmpty ? null : save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(busy ? 'Saving…' : 'Save address'),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              key: const Key('cancel-address'),
              onPressed: busy ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Cancel'),
            ),
            if (checked && branches.isEmpty) ...[
              const SizedBox(height: 14),
              if (requested)
                const Text('Your request has been sent to Vclean.')
              else
                OutlinedButton(
                  onPressed: busy ? null : requestArea,
                  child: const Text('Request to serve my area'),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
