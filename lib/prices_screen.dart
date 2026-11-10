import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    final colors = Theme.of(context).colorScheme;
    final filtered = items.where((item) => item.matches(search.text)).toList();
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pricing',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh prices',
                        onPressed: loading ? null : refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select branch',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (widget.branches.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.branches
                            .map(
                              (branch) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  key: Key('branch-${branch.id}'),
                                  label: Text(branch.name),
                                  selected: branch.id == branchId,
                                  showCheckmark: false,
                                  selectedColor: colors.primary,
                                  labelStyle: TextStyle(
                                    color: branch.id == branchId
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                  ),
                                  onSelected: (_) {
                                    if (branch.id == branchId) return;
                                    search.clear();
                                    if (scroll.hasClients) scroll.jumpTo(0);
                                    load(branch.id);
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('price-search'),
                    controller: search,
                    onChanged: (_) => setState(() => flippedId = null),
                    decoration: const InputDecoration(
                      hintText: 'Search by item, segment, or service…',
                      prefixIcon: Icon(Icons.search),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      error ??
                          'Branches could not be loaded. Please try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.crossAxisExtent - 12) / 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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
      borderRadius: BorderRadius.circular(16),
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
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
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
