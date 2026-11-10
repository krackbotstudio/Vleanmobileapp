import 'package:flutter/material.dart';
import 'account_data.dart';
import 'account_widgets.dart';
import 'appearance.dart';
import 'auth.dart';
import 'catalog.dart';
import 'domain.dart';

class OrdersScreen extends StatefulWidget {
  final CustomerSession? session;
  final AccountApi api;
  final VoidCallback signIn;
  final PreviewBookings previews;
  const OrdersScreen({
    super.key,
    required this.session,
    required this.api,
    required this.signIn,
    required this.previews,
  });
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  List<CustomerOrder> orders = [];
  bool loading = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final session = widget.session;
    if (session == null) return;
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.orders(session.token);
      if (mounted && request == generation) setState(() => orders = result);
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = failureMessage(e);
          orders = [];
        });
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> open(CustomerOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsScreen(
          api: widget.api,
          token: widget.session!.token,
          orderId: order.id,
        ),
      ),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: ListenableBuilder(
      listenable: widget.previews,
      builder: (context, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Orders',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.session != null)
                IconButton(
                  tooltip: 'Refresh orders',
                  onPressed: loading ? null : refresh,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.session == null
                ? 'Log in to see your active and past orders.'
                : 'Your ongoing and completed orders, with status and service details.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          if (widget.session == null)
            FilledButton(onPressed: widget.signIn, child: const Text('Log in'))
          else if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            AccountError(error!, refresh)
          else if (orders.isEmpty)
            const AccountPanel(child: Text('No orders yet.'))
          else
            ...orders.map((order) {
              final date = calendarDate(order.text('pickupDate'));
              return AccountPanel(
                padding: EdgeInsets.zero,
                child: InkWell(
                  key: Key('order-${order.id}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => open(order),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .06),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                date == null
                                    ? '—'
                                    : shortMonths[date.month - 1],
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                date == null
                                    ? '—'
                                    : date.day.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.walkIn
                                    ? 'Walk in'
                                    : order.text('timeWindow').isEmpty
                                    ? 'No slot selected'
                                    : order.text('timeWindow'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OrderBadge(order),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (widget.previews.orders.isNotEmpty) ...[
            const SectionLabel('Preview bookings'),
            ...widget.previews.orders.map(
              (order) => AccountPanel(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(order.id),
                    subtitle: Text(
                      order.pickup.services
                          .map((service) => service.name)
                          .join(', '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDocument(
                      context,
                      order.id,
                      '${order.pickup.services.map((s) => s.name).join(', ')}\n\n${order.pickup.address}\n${order.pickup.postalCode}\n\n${displayDate(order.pickup.date.toIso8601String())} · ${order.pickup.window}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class OrderDetailsScreen extends StatefulWidget {
  final AccountApi api;
  final String token, orderId;
  const OrderDetailsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.orderId,
  });
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  CustomerOrder? order;
  List<CustomerInvoice> invoices = [];
  String? error, invoiceError;
  bool loading = true, eligible = false, feedbackChecked = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      invoiceError = null;
      eligible = false;
    });
    try {
      final result = await widget.api.order(widget.token, widget.orderId);
      var billing = <CustomerInvoice>[];
      String? billingError;
      try {
        billing =
            result.embeddedInvoices ??
            await widget.api.invoices(widget.token, widget.orderId);
      } catch (e) {
        billingError = failureMessage(e);
      }
      if (!mounted || request != generation) return;
      setState(() {
        order = result;
        invoices = billing;
        invoiceError = billingError;
        loading = false;
      });
      if (result.delivered && result.paid) {
        try {
          final allowed = await widget.api.feedbackEligible(
            widget.token,
            widget.orderId,
          );
          if (!mounted || request != generation) return;
          setState(() => eligible = allowed);
          if (allowed && !feedbackChecked) {
            feedbackChecked = true;
            await feedback();
          }
        } catch (_) {
          /* Feedback never blocks viewing a customer's order. */
        }
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = failureMessage(e);
          order = null;
          loading = false;
        });
      }
    }
  }

  Future<void> feedback() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FeedbackDialog(
        api: widget.api,
        token: widget.token,
        orderId: widget.orderId,
      ),
    );
    if (mounted && sent == true) {
      setState(() => eligible = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. Your feedback has been submitted.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = order;
    final active = invoices.where((invoice) => !invoice.voided).toList();
    final finals = active.where((invoice) => invoice.finalInvoice).toList();
    final visible = finals.isEmpty ? active : finals;
    final bill = visible.firstOrNull;
    final due = current == null || bill == null
        ? null
        : current.paid
        ? 0
        : current.due ??
              (bill.total - invoiceAdvance(bill, active)).clamp(0, bill.total);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh order',
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              AccountError(error!, refresh)
            else if (current != null) ...[
              AccountPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      'Order #${current.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrderBadge(current),
                    const Divider(height: 28),
                    if (current.services.isNotEmpty &&
                        current.services != 'Wash & Fold' &&
                        current.services != 'Services not set')
                      accountDetail(context, 'Services', current.services),
                    accountDetail(
                      context,
                      current.walkIn ? 'Order date' : 'Pickup schedule',
                      '${displayDate(current.text('pickupDate'))} · ${current.walkIn ? 'Walk in' : current.text('timeWindow')}',
                    ),
                    accountDetail(
                      context,
                      'Address details',
                      current.walkIn
                          ? 'Walk in'
                          : [
                              current.text('addressLabel'),
                              current.text('addressLine'),
                              current.text('pincode'),
                            ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                    if (current.cancelled &&
                        current.text('cancellationReason').isNotEmpty)
                      accountDetail(
                        context,
                        'Cancellation reason',
                        current.text('cancellationReason'),
                      ),
                  ],
                ),
              ),
              if (current.trackingStage != null)
                AccountPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Status tracker'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var index = 0; index < 4; index++)
                            Expanded(
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor:
                                        index <= current.trackingStage!
                                        ? const Color(0xFF109C76)
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: .08),
                                    child: Icon(
                                      const [
                                        Icons.check,
                                        Icons.local_laundry_service_outlined,
                                        Icons.local_shipping_outlined,
                                        Icons.done_all,
                                      ][index],
                                      size: 17,
                                      color: index <= current.trackingStage!
                                          ? Colors.white
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: .4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    const [
                                      'Received',
                                      'Processing',
                                      'Out for delivery',
                                      'Delivered',
                                    ][index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: index == current.trackingStage
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (current.text('expectedDeliveryDate').isNotEmpty)
                AccountPanel(
                  child: accountDetail(
                    context,
                    'Expected delivery',
                    displayDate(current.text('expectedDeliveryDate')),
                  ),
                ),
              if (current.paid || due != null)
                AccountPanel(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        current.paid ? 'Payment verified' : 'Amount to pay',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        current.paid ? 'Paid' : rupees(due!),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              const SectionLabel('Invoice breakdown'),
              if (invoiceError != null)
                AccountError(invoiceError!, refresh)
              else if (visible.isEmpty)
                const Text('No invoices yet.')
              else
                ...visible.map(
                  (invoice) => invoiceCard(context, invoice, active, current),
                ),
              if (eligible)
                FilledButton.icon(
                  onPressed: feedback,
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Rate your experience'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget invoiceCard(
    BuildContext context,
    CustomerInvoice invoice,
    List<CustomerInvoice> all,
    CustomerOrder current,
  ) {
    final advance = invoiceAdvance(invoice, all);
    final balance = current.paid
        ? 0
        : (invoice.total - advance).clamp(0, invoice.total);
    Widget total(String name, int value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rupees(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return AccountPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invoice.finalInvoice
                ? 'Final Invoice'
                : invoice.acknowledgement
                ? 'Acknowledgement Invoice'
                : invoice.text('type'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (invoice.text('code').isNotEmpty)
            Text(
              'Invoice No: ${invoice.text('code')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (invoice.text('issuedAt').isNotEmpty)
            Text(
              'Issued: ${displayDate(invoice.text('issuedAt'))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const Divider(height: 24),
          ...invoice.items.map((item) {
            final icon = CatalogItem(
              id: field(item, 'id'),
              name: field(item, 'name'),
              icon: field(item, 'icon'),
              prices: const [],
            ).imageUri;
            final meta = [
              field(item, 'segmentLabel'),
              field(item, 'serviceLabel'),
            ].where((s) => s.isNotEmpty).join(' · ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Image.network(
                        icon.toString(),
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.checkroom, size: 24),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field(item, 'name'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (meta.isNotEmpty)
                          Text(
                            meta,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          '${item['quantity'] ?? '—'} × ${amount(item['unitPrice']) == null ? '—' : rupees(amount(item['unitPrice'])!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (field(item, 'remarks').isNotEmpty)
                          Text(
                            field(item, 'remarks'),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else if (item['clothesCount'] != null)
                          Text(
                            'Clothes: ${item['clothesCount']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amount(item['amount']) == null
                        ? '—'
                        : rupees(amount(item['amount'])!),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          if (invoice.money('subtotal') != null)
            total('Subtotal', invoice.money('subtotal')!),
          if (invoice.money('tax') != null) total('Tax', invoice.money('tax')!),
          if ((invoice.money('discountPaise') ?? 0) > 0)
            total('Discount', -invoice.money('discountPaise')!),
          total('Total', invoice.total, bold: true),
          if (advance > 0) total('Advance paid', advance),
          if (advance > 0 || current.paid)
            total(
              current.paid ? 'Balance paid' : 'Balance due',
              balance,
              bold: true,
            ),
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  final AccountApi api;
  final String token, orderId;
  const _FeedbackDialog({
    required this.api,
    required this.token,
    required this.orderId,
  });
  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  int rating = 0;
  bool busy = false;
  String? error;
  final comment = TextEditingController();
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (rating == 0) {
      setState(() => error = 'Please select a star rating.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.feedback(
        widget.token,
        widget.orderId,
        rating,
        comment.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failureMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('How was your experience?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Expanded(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: '$i stars',
                      onPressed: busy ? null : () => setState(() => rating = i),
                      icon: Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFD99A2A),
                      ),
                    ),
                  ),
              ],
            ),
            TextField(
              controller: comment,
              enabled: !busy,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(hintText: 'Optional comment'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Submitting…' : 'Submit'),
        ),
      ],
    ),
  );
}
