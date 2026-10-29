const _months = [
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
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Oct 29, 2026
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// 16:59
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Today · 16:59", "Yesterday · 09:12" or "Oct 21, 2026 · 08:30"
String formatDateTimeShort(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final label = switch (diff) {
    0 => 'Today',
    1 => 'Yesterday',
    -1 => 'Tomorrow',
    _ => formatDate(d),
  };
  return '$label · ${formatTime(d)}';
}
