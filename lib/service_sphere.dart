import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  const ServiceSphere({super.key});

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
          final maxH = constraints.maxHeight;
          final maxW = constraints.maxWidth;
          final logoSize = maxH.isFinite
              ? math.min(130.0, math.max(60.0, maxH - 100))
              : math.min(130.0, math.max(80.0, maxW * 0.32));

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Big Chrome Logo without background circle
              Center(
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/vclean-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'VCLEAN LAUNDRY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.8,
                  color: ink.withValues(alpha: dark ? .75 : .7),
                ),
              ),
              const SizedBox(height: 10),
              // Continuous ribbon scrolling services below logo (not chips)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0x18FFFFFF)
                      : const Color(0xFFF3F4F7),
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
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
                    final newOffset = (scrollController.offset - details.delta.dx)
                        .clamp(0.0, scrollController.position.maxScrollExtent);
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
                              color: ink.withValues(
                                alpha: dark ? 0.35 : 0.3,
                              ),
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
                              color: ink.withValues(
                                alpha: dark ? 0.75 : 0.65,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                color: ink.withValues(
                                  alpha: dark ? 0.9 : 0.85,
                                ),
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
