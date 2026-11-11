import 'package:flutter/material.dart';

import 'appearance.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
            Expanded(
              child: Text(
                'Select pickup date',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
            NeuIconButton(
              key: const Key('pickup-calendar'),
              icon: Icons.calendar_month_outlined,
              tooltip: 'Choose another date',
              size: 40,
              onPressed: calendar,
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
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final day = days[index];
              final active = DateUtils.isSameDay(day, selectedDate);
              final ink = active
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface;
              return Semantics(
                button: true,
                selected: active,
                label: labels.formatFullDate(day),
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: active
                        ? brandRaised(radius: 18)
                        : neuRaised(dark, radius: 18, depth: 4),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
        Text(
          'Select time slot',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var index = 0; index < sampleWindows.length; index++)
                SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: NeuOption(
                    key: Key('pickup-window-$index'),
                    selected:
                        selectedDate != null && window == sampleWindows[index],
                    radius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    onTap: selectedDate == null
                        ? null
                        : () => onWindowChanged(sampleWindows[index]),
                    child: Text(
                      sampleWindows[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
