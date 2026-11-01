import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Rounded panel with a soft border, used for every block on the dashboard.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.all(20),
    this.flushBody = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;

  /// Body touches the panel edges (tables).
  final bool flushBody;

  @override
  Widget build(BuildContext context) {
    final header = title == null
        ? null
        : Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, flushBody ? 14 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 13, color: AC.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                ?action,
              ],
            ),
          );
    return Container(
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AC.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?header,
          if (flushBody)
            child
          else
            Padding(
              padding: title == null ? padding : padding.copyWith(top: 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Stat card: icon tile, label, big value, small footnote.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.foot,
    this.footColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? foot;
  final Color? footColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AC.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AC.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AC.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (foot != null) ...[
                const SizedBox(height: 6),
                Text(
                  foot!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: footColor ?? AC.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloured pill for statuses.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.dot = true});
  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials avatar.
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 36, this.color});
  final String name;
  final double size;
  final Color? color;

  static const _palette = [
    AC.primary,
    AC.blue,
    AC.purple,
    AC.orange,
    AC.teal,
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final ini = parts
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0])
        .join()
        .toUpperCase();
    final c = color ?? _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Text(
        ini,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Page title row with optional actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(color: AC.muted)),
              ],
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

/// Lime/green filled button like "Onboard school".
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: danger ? AC.red : AC.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AC.border,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Urbanist',
        ),
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon ?? Icons.check, size: 18),
      label: Text(label),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? AC.text,
        side: BorderSide(color: color?.withValues(alpha: 0.5) ?? AC.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Urbanist',
        ),
      ),
      icon: Icon(icon ?? Icons.tune, size: 18),
      label: Text(label),
    );
  }
}

/// Simple responsive table: header row + rows, horizontally scrollable on
/// narrow screens.
class DataGrid extends StatelessWidget {
  const DataGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.flex,
    this.onRowTap,
    this.minWidth = 760,
    this.empty = 'Nothing to show',
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final ValueChanged<int>? onRowTap;
  final double minWidth;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final f = flex ?? List.filled(columns.length, 1);
    Widget row(List<Widget> cells, {bool header = false, int? index}) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: f[i],
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: cells[i],
                  ),
                ),
              ),
          ],
        ),
      );
      return Container(
        decoration: BoxDecoration(
          color: header ? AC.cardHigh : null,
          border: Border(top: BorderSide(color: AC.border)),
        ),
        child: index == null || onRowTap == null
            ? content
            : InkWell(onTap: () => onRowTap!(index), child: content),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth < minWidth ? minWidth : c.maxWidth;
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row([
                for (final h in columns)
                  Text(
                    h,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AC.muted,
                    ),
                  ),
              ], header: true),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(36),
                  child: Center(
                    child: Text(empty, style: TextStyle(color: AC.muted)),
                  ),
                ),
              for (var i = 0; i < rows.length; i++) row(rows[i], index: i),
            ],
          ),
        );
        if (c.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        );
      },
    );
  }
}

/// Two-line cell: bold title + muted subtitle.
class CellTitle extends StatelessWidget {
  const CellTitle(this.title, this.sub, {super.key, this.leading});
  final String title;
  final String? sub;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AC.muted),
          ),
      ],
    );
    if (leading == null) return text;
    return Row(
      children: [
        leading!,
        const SizedBox(width: 12),
        Flexible(child: text),
      ],
    );
  }
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13.5});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: AC.muted, fontSize: size),
  );
}

/// Search box used on list pages.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search, color: AC.muted, size: 20),
        ),
      ),
    );
  }
}

/// Row of filter chips.
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.counts,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, int>? counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(counts?[o] == null ? o : '$o  ${counts![o]}'),
            selected: value == o,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: value == o ? Colors.white : AC.text,
            ),
            onSelected: (_) => onChanged(o),
          ),
      ],
    );
  }
}

/// Lays children out in a responsive grid of equal-width columns.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        var cols = (c.maxWidth / minItemWidth).floor().clamp(
          1,
          children.length,
        );
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  String ok = 'Confirm',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Text(body, style: TextStyle(color: AC.muted, height: 1.5)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: AC.muted)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AC.red : AC.primary,
          ),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// "2h ago", "3d ago"
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${d.inDays ~/ 30}mo ago';
}

/// ₦1.2m / ₦350k compact naira.
String nairaCompact(num v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000)
    return '$sign₦${(a / 1000000).toStringAsFixed(a >= 10000000 ? 0 : 1)}m';
  if (a >= 1000)
    return '$sign₦${(a / 1000).toStringAsFixed(a >= 100000 ? 0 : 1)}k';
  return '$sign₦${a.round()}';
}
