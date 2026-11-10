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
  const LoginScreen({
    super.key,
    this.brand,
    this.enableVideo = true,
    required this.auth,
    this.now,
    required this.onAuthenticated,
  });
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
  Widget build(BuildContext context) => Theme(
    data: customerTheme(true),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (widget.enableVideo && !MediaQuery.disableAnimationsOf(context))
          const LoginVideo(),
        const ColoredBox(color: Color(0x9E000000)),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 118),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 138).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 388),
                  child: AutofillGroup(
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/vclean-logo.png',
                              width: requestId == null ? 108 : 80,
                              height: requestId == null ? 108 : 80,
                              semanticLabel: 'Vclean Laundry logo',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            requestId == null
                                ? (widget.brand?.name ?? 'Vclean Laundry')
                                : 'Verification Code',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (requestId == null) ...[
                            const Text(
                              'LAUNDRY  •  DRY CLEAN  •  IRONING',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xA6FFFFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: TextFormField(
                                    initialValue: '+91',
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('phone'),
                                    controller: phone,
                                    enabled: !busy,
                                    keyboardType: TextInputType.phone,
                                    autofillHints: const [
                                      AutofillHints.telephoneNumberNational,
                                    ],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Enter mobile number',
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.all(13),
                                        child: FaIcon(
                                          FontAwesomeIcons.whatsapp,
                                          color: Color(0xFF25D366),
                                          size: 22,
                                        ),
                                      ),
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
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                legalPill(
                                  context,
                                  'Terms & Conditions',
                                  widget.brand?.terms ?? '',
                                ),
                                legalPill(
                                  context,
                                  'Privacy Policy',
                                  widget.brand?.privacy ?? '',
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Enter the 6-digit code sent to +91 $requestedPhone',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xBFFFFFFF),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              key: const Key('otp-code'),
                              controller: code,
                              enabled: !busy,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                letterSpacing: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: const InputDecoration(
                                labelText: '6-digit code',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              validator: (value) =>
                                  RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                  ? null
                                  : 'Enter the 6-digit code.',
                              onFieldSubmitted: (_) => confirm(),
                            ),
                          ],
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF8C8C),
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          FilledButton(
                            key: Key(
                              requestId == null ? 'send-otp' : 'verify-otp',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed:
                                busy || (requestId == null && remaining > 0)
                                ? null
                                : requestId == null
                                ? () => requestCode()
                                : confirm,
                            child: Text(
                              busy
                                  ? (requestId == null
                                        ? 'Sending…'
                                        : 'Verifying…')
                                  : requestId == null
                                  ? (remaining > 0
                                        ? 'Try again in ${remaining}s'
                                        : 'Accept & Send OTP')
                                  : 'Confirm',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (requestId != null) ...[
                            const SizedBox(height: 12),
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
                          const SizedBox(height: 14),
                          const StudioCredit(forceWhite: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget legalPill(BuildContext context, String label, String body) => Material(
    color: const Color(0x1AFFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0x33FFFFFF)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showDocument(context, label, body),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
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
      Image.asset(
        'assets/tectangle-logo.png',
        width: 85,
        height: 22,
        fit: BoxFit.contain,
        color: !forceWhite && Theme.of(context).brightness == Brightness.light
            ? Theme.of(context).colorScheme.onSurface
            : null,
        colorBlendMode: BlendMode.srcIn,
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
