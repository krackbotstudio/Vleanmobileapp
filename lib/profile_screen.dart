import 'package:flutter/material.dart';
import 'account_data.dart';
import 'account_widgets.dart';
import 'addresses_screen.dart';
import 'appearance.dart';
import 'auth.dart';
import 'brand_api.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final CustomerSession? session;
  final BrandInfo? brand;
  final AccountApi api;
  final VoidCallback signIn, openOrders;
  final Future<void> Function() signOut;
  final ValueChanged<CustomerProfile> onProfileChanged;
  const ProfileScreen({
    super.key,
    required this.session,
    required this.brand,
    required this.api,
    required this.signIn,
    required this.signOut,
    required this.openOrders,
    required this.onProfileChanged,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController(), email = TextEditingController();
  final form = GlobalKey<FormState>();
  CustomerProfile? customer;
  bool loading = false, saving = false, leaving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    customer = widget.session?.customer;
    name.text = customer?.name ?? '';
    email.text = customer?.email ?? '';
    refresh();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (widget.session == null || loading || saving) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fresh = await widget.api.profile(widget.session!.token);
      if (!mounted) return;
      if (fresh.id != widget.session!.customer.id) {
        throw const FormatException('Profile mismatch');
      }
      setState(() {
        customer = fresh;
        name.text = fresh.name ?? '';
        email.text = fresh.email ?? '';
      });
      widget.onProfileChanged(fresh);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || loading || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.updateProfile(
        widget.session!.token,
        name.text,
        email.text,
      );
      final fresh = await widget.api.profile(widget.session!.token);
      if (!mounted) return;
      if (fresh.id != widget.session!.customer.id) {
        throw const FormatException('Profile mismatch');
      }
      setState(() {
        customer = fresh;
        name.text = fresh.name ?? '';
        email.text = fresh.email ?? '';
      });
      widget.onProfileChanged(fresh);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> logout() async {
    if (leaving) return;
    setState(() => leaving = true);
    try {
      await widget.signOut();
    } finally {
      if (mounted) setState(() => leaving = false);
    }
  }

  Widget action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    String? subtitle,
    bool danger = false,
  }) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: IconChip(
          Icon(
            icon,
            color: danger ? color : Theme.of(context).colorScheme.primary,
            size: 19,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: danger ? color : mutedText(context),
          size: 22,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget fieldIcon(IconData icon) =>
      IconChip(Icon(icon, size: 19, color: mutedText(context)));

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.session != null;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: neuRaised(
                    Theme.of(context).brightness == Brightness.dark,
                    radius: 32,
                    depth: 9,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(BrandColors.logo, width: 84, height: 84),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  signedIn
                      ? (customer?.name?.trim().isNotEmpty == true
                            ? customer!.name!
                            : 'Your Name')
                      : 'Welcome',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  signedIn
                      ? (customer?.phone != null && customer!.phone.isNotEmpty
                            ? '+91 ${customer!.phone}'
                            : (customer?.email ?? ''))
                      : 'Sign in to manage your profile and addresses',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: mutedText(context),
                  ),
                ),
                if (!signedIn)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(220, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      onPressed: widget.signIn,
                      child: const Text('Log in / Sign up'),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading) const LinearProgressIndicator(),
                if (error != null) AccountError(error!, refresh),
                if (signedIn) ...[
                  const SectionLabel('Edit Profile'),
                  AccountPanel(
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NeuField(
                            leading: fieldIcon(Icons.person_outline_rounded),
                            child: TextFormField(
                              key: const Key('profile-name'),
                              controller: name,
                              enabled: !loading && !saving,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              decoration: neuBareField.copyWith(
                                labelText: 'Name',
                                hintText: 'Full name',
                                counterText: '',
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Enter your name.'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          NeuField(
                            leading: fieldIcon(Icons.mail_outline_rounded),
                            child: TextFormField(
                              key: const Key('profile-email'),
                              controller: email,
                              enabled: !loading && !saving,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 254,
                              decoration: neuBareField.copyWith(
                                labelText: 'Email (optional)',
                                counterText: '',
                              ),
                              validator: (v) =>
                                  (v ?? '').trim().isNotEmpty &&
                                      !RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch(v!.trim())
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          NeuField(
                            leading: fieldIcon(Icons.phone_iphone_rounded),
                            child: InputDecorator(
                              decoration: neuBareField.copyWith(
                                labelText: 'Mobile (cannot be changed)',
                                suffixIcon: Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: mutedText(context),
                                ),
                              ),
                              child: Text(customer?.phone ?? ''),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            key: const Key('profile-save'),
                            onPressed: loading || saving ? null : save,
                            child: Text(saving ? 'Saving…' : 'Save changes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SectionLabel('Quick Actions'),
                  AccountPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        action(
                          Icons.location_on_outlined,
                          'My Addresses',
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddressesScreen(
                                api: widget.api,
                                session: CustomerSession(
                                  widget.session!.token,
                                  customer ?? widget.session!.customer,
                                ),
                              ),
                            ),
                          ),
                          subtitle: 'Manage saved pickup locations',
                        ),
                        const Divider(height: 1, indent: 70, endIndent: 16),
                        action(
                          Icons.receipt_long_outlined,
                          'My Orders',
                          widget.openOrders,
                          subtitle: 'View past and ongoing orders',
                        ),
                      ],
                    ),
                  ),
                ],
                SectionLabel(signedIn ? 'Legal & Account' : 'Legal'),
                AccountPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      action(
                        Icons.description_outlined,
                        'Terms and conditions',
                        () => showDocument(
                          context,
                          'Terms and conditions',
                          widget.brand?.terms ?? '',
                        ),
                      ),
                      const Divider(height: 1, indent: 70, endIndent: 16),
                      action(
                        Icons.policy_outlined,
                        'Privacy policy',
                        () => showDocument(
                          context,
                          'Privacy policy',
                          widget.brand?.privacy ?? '',
                        ),
                      ),
                      if (signedIn) ...[
                        const Divider(height: 1, indent: 70, endIndent: 16),
                        action(
                          Icons.delete_outline,
                          'Delete account',
                          () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete account'),
                              content: const Text(
                                'To delete your account and associated data, please contact Vclean support. Your data will be removed as described in the privacy policy.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ),
                          danger: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (signedIn)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: OutlinedButton.icon(
                      key: const Key('profile-sign-out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: leaving || saving ? null : logout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(leaving ? 'Logging out…' : 'Log out'),
                    ),
                  ),
                const SizedBox(height: 16),
                const StudioCredit(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
