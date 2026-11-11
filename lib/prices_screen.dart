import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'appearance.dart';
import 'brand_api.dart';
import 'catalog.dart';
import 'customer_api.dart';

class PricesScreen extends StatefulWidget {
  final List<Branch> branches;
  final CatalogLoader loadCatalogue;
  final Future<void> Function()? refreshBranches;
  const PricesScreen({
    super.key,
    required this.branches,
    required this.loadCatalogue,
    this.refreshBranches,
  });
  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  final scroll = ScrollController();
  String? branchId, flippedId, error;
  List<CatalogItem> items = [];
  bool loading = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    syncBranch();
  }

  @override
  void didUpdateWidget(covariant PricesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.branches.any((b) => b.id == branchId)) syncBranch();
  }

  void syncBranch() {
    final next = widget.branches.isEmpty ? null : widget.branches.first.id;
    branchId = next;
    if (next != null) {
      load(next);
    } else {
      generation++;
      items = [];
      loading = false;
      error = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && branchId != null && !loading) {
      unawaited(refresh());
    }
  }

  Future<void> load(String id) async {
    final request = ++generation;
    setState(() {
      branchId = id;
      loading = true;
      error = null;
      items = [];
      flippedId = null;
    });
    try {
      final result = await widget.loadCatalogue(id);
      if (!mounted || request != generation) return;
      setState(() {
        items = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted || request != generation) return;
      setState(() {
        loading = false;
        error = e is ApiException
            ? e.message
            : 'Prices could not be loaded. Please try again.';
      });
    }
  }

  Future<void> refresh() async {
    if (widget.refreshBranches != null) await widget.refreshBranches!();
    if (!mounted) return;
    if (branchId != null) {
      await load(branchId!);
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((item) => item.matches(search.text)).toList();
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    'Pricing',
                    subtitle: 'Tap any item to flip it and see its prices.',
                    actions: [
                      NeuIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh prices',
                        onPressed: loading ? null : refresh,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Select branch',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.branches.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: widget.branches
                            .map(
                              (branch) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: NeuOption(
                                  key: Key('branch-${branch.id}'),
                                  selected: branch.id == branchId,
                                  radius: 22,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 11,
                                  ),
                                  onTap: () {
                                    if (branch.id == branchId) return;
                                    search.clear();
                                    if (scroll.hasClients) scroll.jumpTo(0);
                                    load(branch.id);
                                  },
                                  child: Text(
                                    branch.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  NeuField(
                    leading: IconChip(
                      Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: mutedText(context),
                      ),
                    ),
                    child: TextField(
                      key: const Key('price-search'),
                      controller: search,
                      onChanged: (_) => setState(() => flippedId = null),
                      decoration: neuBareField.copyWith(
                        hintText: 'Search by item, segment, or service…',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading catalogue prices…'),
                  ],
                ),
              ),
            )
          else if (error != null || branchId == null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: neuRaised(
                  Theme.of(context).brightness == Brightness.dark,
                  radius: 26,
                  depth: 7,
                ),
                child: Column(
                  children: [
                    IconChip(
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 22,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      size: 48,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      error ??
                          'Branches could not be loaded. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.4, color: mutedText(context)),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: refresh,
                      child: const Text('Retry prices'),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  items.isEmpty
                      ? 'No catalogue prices are available for this branch yet.'
                      : 'No matching items. Try another search.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.crossAxisExtent - 16) / 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: math.max(206, width * 1.28),
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = filtered[index];
                      return PriceFlipCard(
                        key: ValueKey('$branchId/${item.id}'),
                        item: item,
                        flipped: flippedId == item.id,
                        onTap: () => setState(
                          () =>
                              flippedId = flippedId == item.id ? null : item.id,
                        ),
                      );
                    }, childCount: filtered.length),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class PriceFlipCard extends StatelessWidget {
  final CatalogItem item;
  final bool flipped;
  final VoidCallback onTap;
  const PriceFlipCard({
    super.key,
    required this.item,
    required this.flipped,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${item.name}, tap to ${flipped ? 'see image' : 'see prices'}',
    child: InkWell(
      key: Key('price-${item.id}'),
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: flipped ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        builder: (context, value, _) {
          final back = value >= .5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY(value * math.pi),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(back ? math.pi : 0),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: neuRaised(
                  Theme.of(context).brightness == Brightness.dark,
                  radius: 22,
                  depth: 6,
                ),
                child: back ? backFace(context) : frontFace(context),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget fromPrice(BuildContext context) => item.startingPrice == null
      ? const SizedBox.shrink()
      : Text(
          'From ${rupees(item.startingPrice!)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
  Widget frontFace(BuildContext context) => Column(
    children: [
      Expanded(
        child: SizedBox(
          width: double.infinity,
          child: CatalogArt(item: item),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          children: [
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            fromPrice(context),
          ],
        ),
      ),
    ],
  );
  Widget backFace(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        fromPrice(context),
        const Divider(height: 18),
        Expanded(
          child: item.prices.isEmpty
              ? const Text(
                  'No prices listed yet.',
                  style: TextStyle(fontSize: 11),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final price in item.prices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      price.segment,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      price.service,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rupees(price.paise),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to return',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    ),
  );
}

class CatalogArt extends StatelessWidget {
  final CatalogItem item;
  const CatalogArt({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(
        switch (item.icon) {
          'human-male' => Icons.man,
          'human-female' => Icons.woman,
          'human-child' => Icons.child_care,
          'washing-machine' ||
          'tumble-dryer' => Icons.local_laundry_service_outlined,
          'coat-rack' => Icons.checkroom,
          'plus-circle' => Icons.add_circle_outline,
          _ => Icons.checkroom,
        },
        size: 52,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    final image = item.imageUri;
    return image == null
        ? fallback
        : Image.network(
            image.toString(),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          );
  }
}
