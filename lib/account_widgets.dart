import 'package:flutter/material.dart';
import 'account_data.dart';
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
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161722)
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: child,
  );
}

class AccountError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const AccountError(this.message, this.retry, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
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
    final isDelivered = order.delivered || st.contains('DELIVER') || st.contains('COMPLET');

    Color bg;
    Color textColor;
    bool isFilled = false;

    if (isPaid || isDelivered) {
      bg = const Color(0xFF047857);
      textColor = Colors.white;
      isFilled = true;
    } else if (st.contains('CONFIRM') || st.contains('RECEIV') || st.contains('SCHEDUL')) {
      bg = dark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      textColor = dark ? const Color(0xFF34D399) : const Color(0xFF10B981);
    } else if (order.cancelled || st.contains('CANCEL') || st.contains('FAIL')) {
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
