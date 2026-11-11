import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'appearance.dart';

enum _Phase { splash, language, welcome }

class IntroCopy {
  final String chooseLanguage;
  final String headline;
  final String anywhere;
  final String getStarted;
  final String haveAccount;
  final String termsLead;
  final String terms;
  final String between;
  final String privacy;
  const IntroCopy({
    required this.chooseLanguage,
    required this.headline,
    required this.anywhere,
    required this.getStarted,
    required this.haveAccount,
    required this.termsLead,
    required this.terms,
    required this.between,
    required this.privacy,
  });

  static const en = IntroCopy(
    chooseLanguage: 'Choose Your Language',
    headline: 'Laundry, done for you.',
    anywhere: 'Anytime, anywhere.',
    getStarted: 'Get Started',
    haveAccount: 'I already have an account',
    termsLead: 'By continuing, you agree to our ',
    terms: 'Terms of Service',
    between: ' and ',
    privacy: 'Privacy Policy',
  );

  static const ta = IntroCopy(
    chooseLanguage: 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
    headline: 'சலவை, உங்களுக்காக.',
    anywhere: 'எப்போது வேண்டுமானாலும், எங்கும்.',
    getStarted: 'தொடங்குங்கள்',
    haveAccount: 'எனக்கு ஏற்கனவே கணக்கு உள்ளது',
    termsLead: 'தொடர்வதன் மூலம், எங்கள் ',
    terms: 'சேவை விதிமுறைகள்',
    between: ' மற்றும் ',
    privacy: 'தனியுரிமைக் கொள்கையை ஏற்கிறீர்கள்.',
  );

  static const ml = IntroCopy(
    chooseLanguage: 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
    headline: 'അലക്കൽ, നിങ്ങൾക്കായി.',
    anywhere: 'എപ്പോൾ വേണമെങ്കിലും, എവിടെയും.',
    getStarted: 'ആരംഭിക്കുക',
    haveAccount: 'എനിക്ക് ഇതിനകം അക്കൗണ്ട് ഉണ്ട്',
    termsLead: 'തുടരുന്നതിലൂടെ, ഞങ്ങളുടെ ',
    terms: 'സേവന നിബന്ധനകൾ',
    between: 'യും ',
    privacy: 'സ്വകാര്യതാ നയവും നിങ്ങൾ അംഗീകരിക്കുന്നു.',
  );

  static const hi = IntroCopy(
    chooseLanguage: 'अपनी भाषा चुनें',
    headline: 'लॉन्ड्री, आपके लिए.',
    anywhere: 'कभी भी, कहीं भी.',
    getStarted: 'शुरू करें',
    haveAccount: 'मेरे पास पहले से खाता है',
    termsLead: 'जारी रखकर, आप हमारी ',
    terms: 'सेवा की शर्तों',
    between: ' और ',
    privacy: 'गोपनीयता नीति से सहमत होते हैं.',
  );

  static IntroCopy of(String code) => switch (code) {
    'ta' => ta,
    'ml' => ml,
    'hi' => hi,
    _ => en,
  };
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: BrandColors.purpleDeep,
    body: BrandBackdrop(child: Center(child: _LogoMark(width: 210))),
  );
}

class WelcomeFlow extends StatefulWidget {
  final String language;
  final ValueChanged<String> onLanguage;
  final ValueChanged<bool> onFinished;
  const WelcomeFlow({
    super.key,
    required this.language,
    required this.onLanguage,
    required this.onFinished,
  });

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow>
    with SingleTickerProviderStateMixin {
  _Phase phase = _Phase.splash;
  String? selected;
  Timer? timer;
  late final AnimationController intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => phase = _Phase.language);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    intro.dispose();
    super.dispose();
  }

  void pick(String code) {
    widget.onLanguage(code);
    setState(() => selected = code);
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 240), () {
      if (mounted) setState(() => phase = _Phase.welcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = IntroCopy.of(widget.language);
    return Scaffold(
      backgroundColor: BrandColors.purpleDeep,
      body: BrandBackdrop(
        child: switch (phase) {
          _Phase.splash => FadeTransition(
            opacity: CurvedAnimation(parent: intro, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: .92, end: 1).animate(
                CurvedAnimation(parent: intro, curve: Curves.easeOutCubic),
              ),
              child: const Center(child: _LogoMark(width: 210)),
            ),
          ),
          _Phase.language => _LanguageStep(
            copy: copy,
            selected: selected,
            onPick: pick,
          ),
          _Phase.welcome => _WelcomeStep(
            copy: copy,
            onGetStarted: () => widget.onFinished(false),
            onHaveAccount: () => widget.onFinished(true),
          ),
        },
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double width;
  const _LogoMark({required this.width});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .18),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        BrandColors.logo,
        width: width,
        semanticLabel: 'Vclean',
      ),
    ),
  );
}

class _GlassHero extends StatelessWidget {
  const _GlassHero();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 220,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .42),
                    Colors.white.withValues(alpha: .12),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .6),
                  width: 1.4,
                ),
              ),
              child: const Icon(
                Icons.local_laundry_service_rounded,
                size: 92,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 6,
          right: 8,
          child: Icon(Icons.auto_awesome, size: 40, color: Colors.white),
        ),
        Positioned(
          bottom: 22,
          left: 6,
          child: Icon(
            Icons.auto_awesome,
            size: 22,
            color: Colors.white.withValues(alpha: .8),
          ),
        ),
      ],
    ),
  );
}

class _LanguageStep extends StatelessWidget {
  final IntroCopy copy;
  final String? selected;
  final ValueChanged<String> onPick;
  const _LanguageStep({
    required this.copy,
    required this.selected,
    required this.onPick,
  });

  static const options = [
    ('en', 'English'),
    ('ta', 'தமிழ்'),
    ('ml', 'മലയാളം'),
    ('hi', 'हिन्दी'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Opacity(
                opacity: .55,
                child: Image.asset(BrandColors.logo, width: 170),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: GlassPanel(
            radius: 28,
            tint: const Color(0xF2FFFFFF),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  copy.chooseLanguage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BrandColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in options) ...[
                  _LanguageButton(
                    label: option.$2,
                    selected: selected == option.$1,
                    onTap: () => onPick(option.$1),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? BrandColors.purpleSoft : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? BrandColors.purple : const Color(0xFFE4D4F2),
        width: selected ? 1.6 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? BrandColors.purple : BrandColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeStep extends StatelessWidget {
  final IntroCopy copy;
  final VoidCallback onGetStarted;
  final VoidCallback onHaveAccount;
  const _WelcomeStep({
    required this.copy,
    required this.onGetStarted,
    required this.onHaveAccount,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _LogoMark(width: 120),
        const Expanded(child: Center(child: _GlassHero())),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassPanel(
            radius: 32,
            tint: const Color(0xF7FFFFFF),
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  copy.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BrandColors.ink,
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  copy.anywhere,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BrandColors.ink,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  key: const Key('intro-get-started'),
                  onPressed: onGetStarted,
                  child: Text(copy.getStarted),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('intro-have-account'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1EEF4),
                    foregroundColor: BrandColors.ink,
                  ),
                  onPressed: onHaveAccount,
                  child: Text(copy.haveAccount),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF6E6578),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: copy.termsLead),
                      TextSpan(
                        text: copy.terms,
                        style: const TextStyle(
                          color: BrandColors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: copy.between),
                      TextSpan(
                        text: copy.privacy,
                        style: const TextStyle(
                          color: BrandColors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
