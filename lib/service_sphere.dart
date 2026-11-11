import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'appearance.dart';
import 'brand_illustrations.dart';

class _ServiceItem {
  final String name;
  final IconData icon;
  const _ServiceItem(this.name, this.icon);
}

const _services = [
  _ServiceItem('Wash & Fold', Icons.local_laundry_service_outlined),
  _ServiceItem('Wash & Iron', Icons.iron_outlined),
  _ServiceItem('Dry Clean', Icons.dry_cleaning_outlined),
  _ServiceItem('Shoe Cleaning', Icons.cleaning_services_outlined),
  _ServiceItem('Steam Iron', Icons.waves_rounded),
  _ServiceItem('Home Linen', Icons.bed_outlined),
];

class ServiceSphere extends StatefulWidget {
  final List<String> banners;
  const ServiceSphere({super.key, this.banners = const []});

  @override
  State<ServiceSphere> createState() => _ServiceSphereState();
}

class _ServiceSphereState extends State<ServiceSphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final ScrollController scrollController = ScrollController();
  bool paused = false, reduceMotion = false;
  bool userDragging = false;

  @override
  void initState() {
    super.initState();
    rotation.addListener(_handleTick);
  }

  void _handleTick() {
    if (userDragging || !scrollController.hasClients) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final half = maxScroll / 2;
    final next = scrollController.offset + 0.6;
    if (next >= half) {
      scrollController.jumpTo(next - half);
    } else {
      scrollController.jumpTo(next);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    syncMotion();
  }

  void syncMotion() {
    if (paused || reduceMotion || !TickerMode.valuesOf(context).enabled) {
      rotation.stop();
    } else if (!rotation.isAnimating) {
      rotation.repeat();
    }
  }

  @override
  void dispose() {
    rotation.removeListener(_handleTick);
    rotation.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: 'Vclean services: ${_services.map((s) => s.name).join(', ')}.',
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final carouselHeight = constraints.maxHeight.isFinite
              ? math.max(120.0, constraints.maxHeight - 84)
              : math.max(150.0, constraints.maxWidth * .44);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              SizedBox(
                height: carouselHeight,
                child: _BannerCarousel(banners: widget.banners),
              ),
              const SizedBox(height: 12),
              // Continuous ribbon scrolling services below logo (not chips)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0x18FFFFFF)
                      : const Color(0xFFF3E7FB),
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE4D4F2),
                      width: 1,
                    ),
                  ),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    userDragging = true;
                    rotation.stop();
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!scrollController.hasClients) return;
                    final newOffset =
                        (scrollController.offset - details.delta.dx).clamp(
                          0.0,
                          scrollController.position.maxScrollExtent,
                        );
                    scrollController.jumpTo(newOffset);
                  },
                  onHorizontalDragEnd: (_) {
                    userDragging = false;
                    syncMotion();
                  },
                  onHorizontalDragCancel: () {
                    userDragging = false;
                    syncMotion();
                  },
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.05, 0.95, 1.0],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _services.length * 2,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          child: Text(
                            '✦',
                            style: TextStyle(
                              fontSize: 10,
                              color: ink.withValues(alpha: dark ? 0.35 : 0.3),
                            ),
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final item = _services[index % _services.length];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 15,
                              color: ink.withValues(alpha: dark ? 0.75 : 0.65),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                color: ink.withValues(alpha: dark ? 0.9 : 0.85),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _Slide {
  final String title, subtitle;
  final BrandArt art;
  final List<Color> colors;
  const _Slide(this.title, this.subtitle, this.art, this.colors);
}

/// Shown when the backend has no carousel banners for the brand.
const _fallbackSlides = [
  _Slide(
    'Doorstep pickup & delivery',
    'Schedule a pickup in a few taps',
    BrandArt.pickup,
    [Color(0xFF8B5CF6), BrandColors.purple],
  ),
  _Slide(
    'Dry cleaning, done right',
    'Expert care for delicate fabrics',
    BrandArt.dryClean,
    [Color(0xFF6D28D9), BrandColors.purpleDeep],
  ),
  _Slide(
    'Crisp steam ironing',
    'Wrinkle-free clothes, every time',
    BrandArt.steamIron,
    [Color(0xFFA855F7), Color(0xFF6B21A8)],
  ),
];

class _BannerCarousel extends StatefulWidget {
  final List<String> banners;
  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  static const interval = Duration(seconds: 7);
  // Divisible by every count up to 8, so the first slide shows first and
  // the user can still swipe backwards.
  static const startPage = 840;
  final controller = PageController(
    viewportFraction: .9,
    initialPage: startPage,
  );
  Timer? timer;
  int page = startPage;

  int get count => widget.banners.isNotEmpty
      ? widget.banners.length
      : _fallbackSlides.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    restartTimer();
  }

  void restartTimer() {
    timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context) || count < 2) return;
    timer = Timer.periodic(interval, (_) {
      if (!mounted || !controller.hasClients) return;
      controller.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = page % count;
    return Column(
      key: const Key('home-carousel'),
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            clipBehavior: Clip.none,
            onPageChanged: (value) {
              setState(() => page = value);
              restartTimer();
            },
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: DecoratedBox(
                decoration: neuRaised(dark, radius: 24, depth: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: widget.banners.isNotEmpty
                      ? networkSlide(widget.banners[index % count])
                      : fallbackSlide(_fallbackSlides[index % count]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == current ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: i == current ? brandGradient : null,
                  color: i == current
                      ? null
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .18),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget networkSlide(String url) => Image.network(
    url,
    fit: BoxFit.cover,
    width: double.infinity,
    semanticLabel: 'Vclean offer',
    errorBuilder: (_, _, _) => fallbackSlide(_fallbackSlides.first),
  );

  Widget fallbackSlide(_Slide slide) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: slide.colors,
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .1),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: box.maxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'VCLEAN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            slide.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            slide.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .82),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 108),
                  child: ExcludeSemantics(child: BrandIllustration(slide.art)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
