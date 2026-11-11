import 'package:flutter/material.dart';
import 'account_data.dart';
import 'appearance.dart';
import 'customer_api.dart';

String failureMessage(Object error) => error is ApiException
    ? error.message
    : 'These details could not be loaded. Please try again.';
const shortMonths = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];
DateTime? calendarDate(String value) =>
    DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : value);
String displayDate(String value) {
  final date = calendarDate(value);
  return date == null
      ? 'Not set'
      : '${date.day.toString().padLeft(2, '0')} ${shortMonths[date.month - 1]} ${date.year}';
}

class AccountPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AccountPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: padding,
    decoration: neuRaised(
      Theme.of(context).brightness == Brightness.dark,
      radius: 24,
      depth: 7,
    ),
    child: child,
  );
}

class AccountError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const AccountError(this.message, this.retry, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
    decoration: neuRaised(
      Theme.of(context).brightness == Brightness.dark,
      radius: 22,
      depth: 5,
    ),
    child: Row(
      children: [
        IconChip(
          Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
        TextButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 12, left: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class OrderBadge extends StatelessWidget {
  final CustomerOrder order;
  const OrderBadge(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final st = order.status.toUpperCase();
    final isPaid = order.paid;
    final isDelivered =
        order.delivered || st.contains('DELIVER') || st.contains('COMPLET');

    Color bg;
    Color textColor;
    bool isFilled = false;

    if (isPaid || isDelivered) {
      bg = const Color(0xFF047857);
      textColor = Colors.white;
      isFilled = true;
    } else if (st.contains('CONFIRM') ||
        st.contains('RECEIV') ||
        st.contains('SCHEDUL')) {
      bg = dark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      textColor = dark ? const Color(0xFF34D399) : const Color(0xFF10B981);
    } else if (order.cancelled ||
        st.contains('CANCEL') ||
        st.contains('FAIL')) {
      bg = dark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      textColor = dark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
    } else if (order.trackingStage == 1 ||
        st.contains('PROCESS') ||
        st.contains('WASH') ||
        st.contains('IRON') ||
        st.contains('PICK')) {
      bg = dark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      textColor = dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    } else {
      bg = dark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE);
      textColor = dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isFilled
            ? null
            : Border.all(color: textColor.withValues(alpha: dark ? 0.3 : 0.4)),
      ),
      child: Text(
        statusLabel(order.status).toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

Widget accountDetail(BuildContext context, String label, String value) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'Not set' : value,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
