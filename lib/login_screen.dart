import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';

import 'appearance.dart';
import 'auth.dart';
import 'brand_api.dart';
import 'customer_api.dart';

class LoginScreen extends StatefulWidget {
  final BrandInfo? brand;
  final bool enableVideo;
  final CustomerAuth auth;
  final DateTime Function()? now;
  final Future<void> Function(CustomerSession) onAuthenticated;
  final VoidCallback? onSkip;
  const LoginScreen({
    super.key,
    this.brand,
    this.enableVideo = true,
    required this.auth,
    this.now,
    required this.onAuthenticated,
    this.onSkip,
  });
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bareField = neuBareField;
  static const _muted = BrandColors.muted;

  final phone = TextEditingController(), code = TextEditingController();
  final form = GlobalKey<FormState>();
  String? requestId, error;
  String requestedPhone = '';
  bool busy = false;
  DateTime? resendAt;
  Timer? timer;
  DateTime get currentTime => widget.now?.call() ?? DateTime.now();
  int get remaining => resendAt == null
      ? 0
      : (resendAt!.difference(currentTime).inMilliseconds / 1000).ceil().clamp(
          0,
          60,
        );
  void cooldown() {
    timer?.cancel();
    resendAt = currentTime.add(const Duration(seconds: 60));
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (remaining == 0) timer?.cancel();
    });
  }

  Future<void> requestCode({bool resend = false}) async {
    if (busy || remaining > 0) return;
    if (!resend && !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final number = resend ? requestedPhone : phone.text.trim();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.auth.requestOtp(number);
      if (!mounted) return;
      setState(() {
        requestId = result;
        requestedPhone = number;
        code.clear();
        cooldown();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e is ApiException
            ? e.message
            : 'Could not send the code. Please try again.';
        if (e is ApiException && e.status == 429) cooldown();
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    if (busy || requestId == null || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await widget.auth.verifyOtp(
        requestedPhone,
        code.text.trim(),
        requestId!,
      );
      if (!mounted) return;
      await widget.onAuthenticated(session);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException
            ? e.message
            : 'Could not verify the code. Please try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sending = requestId == null;
    final canSubmit = !busy && !(sending && remaining > 0);
    return Theme(
      data: customerTheme(false),
      child: DecoratedBox(
        decoration: pageBackdrop(false),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 60).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AutofillGroup(
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: EdgeInsets.all(sending ? 18 : 14),
                              decoration: neuRaised(
                                false,
                                radius: 36,
                                depth: 9,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  BrandColors.logo,
                                  width: sending ? 112 : 84,
                                  semanticLabel: 'Vclean Laundry logo',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            sending ? 'Welcome Back' : 'Verification Code',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: BrandColors.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sending
                                ? 'Sign in or sign up with your mobile number'
                                : 'Enter the 6-digit code sent to +91 $requestedPhone',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                            decoration: neuRaised(false, radius: 30, depth: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (sending) ...[
                                  raisedField(
                                    Row(
                                      children: [
                                        iconChip(
                                          const FaIcon(
                                            FontAwesomeIcons.whatsapp,
                                            color: Color(0xFF25D366),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          '+91',
                                          style: TextStyle(
                                            color: BrandColors.ink,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 22,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          color: const Color(0xFFD6D7E6),
                                        ),
                                        Expanded(
                                          child: TextFormField(
                                            key: const Key('phone'),
                                            controller: phone,
                                            enabled: !busy,
                                            keyboardType: TextInputType.phone,
                                            autofillHints: const [
                                              AutofillHints
                                                  .telephoneNumberNational,
                                            ],
                                            style: const TextStyle(
                                              color: BrandColors.ink,
                                              fontSize: 15,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                10,
                                              ),
                                            ],
                                            decoration: _bareField.copyWith(
                                              hintText: 'Mobile number',
                                            ),
                                            validator: (value) =>
                                                RegExp(
                                                  r'^[6-9]\d{9}$',
                                                ).hasMatch(value ?? '')
                                                ? null
                                                : 'Enter a valid mobile number.',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      legalLink(
                                        context,
                                        'Terms & Conditions',
                                        widget.brand?.terms ?? '',
                                      ),
                                      const Text(
                                        '·',
                                        style: TextStyle(color: _muted),
                                      ),
                                      legalLink(
                                        context,
                                        'Privacy Policy',
                                        widget.brand?.privacy ?? '',
                                      ),
                                    ],
                                  ),
                                ] else
                                  raisedField(
                                    Row(
                                      children: [
                                        iconChip(
                                          const Icon(
                                            Icons.lock_outline_rounded,
                                            color: _muted,
                                            size: 19,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            key: const Key('otp-code'),
                                            controller: code,
                                            enabled: !busy,
                                            keyboardType: TextInputType.number,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode,
                                            ],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: BrandColors.ink,
                                              fontSize: 24,
                                              letterSpacing: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                6,
                                              ),
                                            ],
                                            decoration: _bareField.copyWith(
                                              hintText: '••••••',
                                            ),
                                            validator: (value) =>
                                                RegExp(
                                                  r'^\d{6}$',
                                                ).hasMatch(value ?? '')
                                                ? null
                                                : 'Enter the 6-digit code.',
                                            onFieldSubmitted: (_) => confirm(),
                                          ),
                                        ),
                                        const SizedBox(width: 50),
                                      ],
                                    ),
                                  ),
                                if (error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: Color(0xFFD64550),
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 22),
                                // Gradient, glow and disabled fade come from
                                // the shared FilledButton theme.
                                FilledButton(
                                  key: Key(sending ? 'send-otp' : 'verify-otp'),
                                  onPressed: canSubmit
                                      ? (sending
                                            ? () => requestCode()
                                            : confirm)
                                      : null,
                                  child: Text(
                                    busy
                                        ? (sending ? 'Sending…' : 'Verifying…')
                                        : sending
                                        ? (remaining > 0
                                              ? 'Try again in ${remaining}s'
                                              : 'Accept & Send OTP')
                                        : 'Confirm',
                                  ),
                                ),
                                if (!sending) ...[
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    key: const Key('resend-otp'),
                                    onPressed: busy || remaining > 0
                                        ? null
                                        : () => requestCode(resend: true),
                                    child: Text(
                                      remaining > 0
                                          ? 'Resend code in ${remaining}s'
                                          : 'Resend code',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    key: const Key('change-phone'),
                                    onPressed: busy
                                        ? null
                                        : () => setState(() {
                                            requestId = null;
                                            code.clear();
                                            error = null;
                                          }),
                                    child: const Text('Change number'),
                                  ),
                                ],
                                if (sending && widget.onSkip != null) ...[
                                  const SizedBox(height: 24),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Color(0xFFD9DAE8),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Color(0xFFD9DAE8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Center(
                                    child: DecoratedBox(
                                      decoration: neuRaised(
                                        false,
                                        radius: 26,
                                        depth: 5,
                                      ),
                                      child: TextButton.icon(
                                        key: const Key('login-skip'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: BrandColors.ink,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 14,
                                          ),
                                          shape: const StadiumBorder(),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onPressed: busy ? null : widget.onSkip,
                                        icon: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 18,
                                          color: BrandColors.purple,
                                        ),
                                        label: const Text('Continue as guest'),
                                      ),
                                    ),
                                  ),
                                ],
                                if (sending) ...[
                                  const SizedBox(height: 22),
                                  const Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                      ),
                                      children: [
                                        TextSpan(text: 'New to Vclean? '),
                                        TextSpan(
                                          text: 'Verify your number to sign up',
                                          style: TextStyle(
                                            color: BrandColors.purple,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const StudioCredit(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget raisedField(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: neuRaised(false, radius: 20, depth: 5),
    child: child,
  );

  Widget iconChip(Widget icon) => IconChip(icon);

  Widget legalLink(BuildContext context, String label, String body) =>
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.purple,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: () => showDocument(context, label, body),
        child: Text(label),
      );
}

class StudioCredit extends StatelessWidget {
  final bool forceWhite;
  const StudioCredit({super.key, this.forceWhite = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          'Designed & Developed by',
          style: TextStyle(
            fontSize: 11,
            color: forceWhite
                ? Colors.white
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .58),
          ),
        ),
      ),
      const SizedBox(width: 6),
      // Full-colour Tectangle mark; the light variant swaps the charcoal
      // lettering for white on dark backgrounds and keeps the yellow.
      Image.asset(
        forceWhite || Theme.of(context).brightness == Brightness.dark
            ? 'assets/tectangle-logo-light.png'
            : 'assets/tectangle-logo.png',
        height: 22,
        fit: BoxFit.contain,
        semanticLabel: 'Tectangle',
      ),
    ],
  );
}

class LoginVideo extends StatefulWidget {
  const LoginVideo({super.key});
  @override
  State<LoginVideo> createState() => _LoginVideoState();
}

class _LoginVideoState extends State<LoginVideo> with WidgetsBindingObserver {
  late final VideoPlayerController controller;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = VideoPlayerController.asset(
      'assets/service-icons/download.mp4',
    );
    initialize();
  }

  Future<void> initialize() async {
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) return;
      setState(() => ready = true);
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await controller.play();
      }
    } catch (_) {
      /* Retain the black background if playback is unavailable. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ready) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !ready
      ? const SizedBox.expand()
      : IgnorePointer(
          child: ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        );
}
