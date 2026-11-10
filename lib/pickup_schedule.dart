import 'package:flutter/material.dart';

import 'domain.dart';

class PickupSchedule extends StatelessWidget {
  final DateTime? date;
  final String? window;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onWindowChanged;
  final VoidCallback onContinue;

  const PickupSchedule({
    super.key,
    required this.date,
    required this.window,
    required this.onDateChanged,
    required this.onWindowChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(now.year, now.month, now.day + 1);
    final last = DateTime(first.year, first.month, first.day + 29);
    final selectedDate =
        date != null && !date!.isBefore(first) && !date!.isAfter(last)
        ? date
        : null;
    final colors = Theme.of(context).colorScheme;
    final labels = MaterialLocalizations.of(context);
    final days = List.generate(
      7,
      (index) => DateTime(first.year, first.month, first.day + index),
    );
    final customDate = selectedDate != null && selectedDate.isAfter(days.last);

    Future<void> calendar() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? first,
        firstDate: first,
        lastDate: last,
        helpText: 'Select pickup date',
      );
      if (picked != null && context.mounted) onDateChanged(picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Select pickup date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              key: const Key('pickup-calendar'),
              tooltip: 'Choose another date',
              onPressed: calendar,
              icon: const Icon(Icons.calendar_month_outlined, size: 22),
            ),
          ],
        ),
        Text(
          selectedDate == null
              ? 'Choose a day that works for you'
              : labels.formatFullDate(selectedDate),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              final active = DateUtils.isSameDay(day, selectedDate);
              final ink = active ? colors.onPrimary : colors.onSurface;
              return Semantics(
                button: true,
                selected: active,
                label: labels.formatFullDate(day),
                child: ExcludeSemantics(
                  child: Material(
                    color: active
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: .06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: active ? colors.primary : colors.outline,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('pickup-day-$index'),
                      onTap: () => onDateChanged(day),
                      child: SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              index == 0
                                  ? 'Tomorrow'
                                  : const [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ][day.weekday - 1],
                              style: TextStyle(
                                color: ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              const [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ][day.month - 1],
                              style: TextStyle(
                                color: ink.withValues(alpha: .7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (customDate) ...[
          const SizedBox(height: 10),
          Text(
            'Selected: ${labels.formatMediumDate(selectedDate)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'Select time slot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < sampleWindows.length; index++)
                SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: OutlinedButton(
                    key: Key('pickup-window-$index'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      backgroundColor:
                          selectedDate != null && window == sampleWindows[index]
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: .04),
                      foregroundColor:
                          selectedDate != null && window == sampleWindows[index]
                          ? colors.onPrimary
                          : colors.onSurface,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: selectedDate == null
                        ? null
                        : () => onWindowChanged(sampleWindows[index]),
                    child: Semantics(
                      selected:
                          selectedDate != null &&
                          window == sampleWindows[index],
                      child: Text(sampleWindows[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('home-continue'),
          onPressed: selectedDate != null && sampleWindows.contains(window)
              ? onContinue
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
