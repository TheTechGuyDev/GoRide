import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/app_button.dart';
import 'scheduled_rides.dart';

/// Result of the schedule sheet: a time, or "ride now".
class ScheduleChoice {
  const ScheduleChoice(this.at);

  /// Null = ride now.
  final DateTime? at;
}

/// Screen 39: pick a day and time (30 min to 7 days ahead).
Future<ScheduleChoice?> showScheduleSheet(
  BuildContext context, {
  DateTime? current,
}) {
  return showModalBottomSheet<ScheduleChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ScheduleSheet(current: current),
  );
}

enum _Day { today, tomorrow, other }

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({this.current});
  final DateTime? current;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  static const _minuteStep = 5;

  late DateTime _date;
  late _Day _day;
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourCtl;
  late final FixedExtentScrollController _minCtl;
  String? _error;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    // Default: the earliest allowed time, rounded up to the next 5 minutes.
    final earliest = DateTime.now().add(
      ScheduledRidesController.minLead + const Duration(minutes: 4),
    );
    final start =
        widget.current ??
        DateTime(
          earliest.year,
          earliest.month,
          earliest.day,
          earliest.hour,
          (earliest.minute ~/ _minuteStep) * _minuteStep,
        );
    _date = DateTime(start.year, start.month, start.day);
    final diff = _date.difference(_today).inDays;
    _day = diff == 0 ? _Day.today : (diff == 1 ? _Day.tomorrow : _Day.other);
    _hour = start.hour;
    _minute = start.minute - start.minute % _minuteStep;
    _hourCtl = FixedExtentScrollController(initialItem: _hour);
    _minCtl = FixedExtentScrollController(initialItem: _minute ~/ _minuteStep);
  }

  @override
  void dispose() {
    _hourCtl.dispose();
    _minCtl.dispose();
    super.dispose();
  }

  DateTime get _chosen =>
      DateTime(_date.year, _date.month, _date.day, _hour, _minute);

  String? _validate(DateTime t) {
    final now = DateTime.now();
    if (t.isBefore(now.add(ScheduledRidesController.minLead))) {
      return 'Choose a time at least 30 minutes from now';
    }
    if (t.isAfter(now.add(ScheduledRidesController.maxLead))) {
      return 'You can schedule up to 7 days ahead';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _today,
      lastDate: _today.add(ScheduledRidesController.maxLead),
    );
    if (picked == null) return;
    final diff = picked.difference(_today).inDays;
    setState(() {
      _date = picked;
      _day = diff == 0 ? _Day.today : (diff == 1 ? _Day.tomorrow : _Day.other);
      _error = null;
    });
  }

  String get _ampm {
    final h12 = _hour % 12 == 0 ? 12 : _hour % 12;
    return '$h12:${_minute.toString().padLeft(2, '0')} ${_hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    Widget dayTab(_Day d, String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _day == d ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _day == d ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );

    Widget wheel({
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int) label,
      required ValueChanged<int> onChanged,
    }) {
      return Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 52,
          perspective: 0.004,
          diameterRatio: 1.6,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) {
            onChanged(i);
            setState(() => _error = null);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (_, i) {
              final selected = controller.hasClients
                  ? controller.selectedItem == i
                  : false;
              return Center(
                child: Text(
                  label(i),
                  style: TextStyle(
                    fontSize: selected ? 34 : 24,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Schedule a Ride',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const Divider(height: 28),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  dayTab(
                    _Day.today,
                    'Today',
                    () => setState(() {
                      _day = _Day.today;
                      _date = _today;
                      _error = null;
                    }),
                  ),
                  dayTab(
                    _Day.tomorrow,
                    'Tomorrow',
                    () => setState(() {
                      _day = _Day.tomorrow;
                      _date = _today.add(const Duration(days: 1));
                      _error = null;
                    }),
                  ),
                  dayTab(
                    _Day.other,
                    _day == _Day.other
                        ? formatDate(_date).split(',').first
                        : 'Select Date',
                    _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Selection band
                  Container(
                    height: 56,
                    decoration: const BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      wheel(
                        controller: _hourCtl,
                        count: 24,
                        label: (i) => i.toString().padLeft(2, '0'),
                        onChanged: (i) => _hour = i,
                      ),
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      wheel(
                        controller: _minCtl,
                        count: 60 ~/ _minuteStep,
                        label: (i) =>
                            (i * _minuteStep).toString().padLeft(2, '0'),
                        onChanged: (i) => _minute = i * _minuteStep,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatDate(_date)} · $_ampm',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: widget.current != null ? 'Ride now' : 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(
                      context,
                      widget.current != null
                          ? const ScheduleChoice(null)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Set Schedule',
                    onPressed: () {
                      final err = _validate(_chosen);
                      if (err != null) return setState(() => _error = err);
                      Navigator.pop(context, ScheduleChoice(_chosen));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
