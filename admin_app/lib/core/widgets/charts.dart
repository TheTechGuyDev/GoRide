import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import 'ui.dart';

/// Smooth area line chart (naira values) with day labels.
class AreaChart extends StatelessWidget {
  const AreaChart({
    super.key,
    required this.values,
    required this.labels,
    this.second,
    this.color = AC.primary,
    this.secondColor = AC.blue,
    this.height = 260,
    this.money = true,
  });

  final List<num> values;
  final List<String> labels;

  /// Optional second series drawn as a thin line.
  final List<num>? second;
  final Color color;
  final Color secondColor;
  final double height;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final all = [...values, ...?second];
    final maxY = all.isEmpty
        ? 1.0
        : max(1.0, all.reduce(max).toDouble() * 1.15);
    final step = max(1, (labels.length / 6).ceil());

    LineChartBarData series(List<num> v, Color c, {bool area = true}) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < v.length; i++)
              FlSpot(i.toDouble(), v[i].toDouble()),
          ],
          isCurved: true,
          curveSmoothness: 0.25,
          preventCurveOverShooting: true,
          color: c,
          barWidth: area ? 3 : 2,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (s, _) => s.x == v.length - 1,
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 4,
              color: c,
              strokeWidth: 2,
              strokeColor: AC.card,
            ),
          ),
          dashArray: area ? null : [6, 4],
          belowBarData: BarAreaData(
            show: area,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0.0)],
            ),
          ),
        );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AC.border, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY / 4,
                getTitlesWidget: (v, meta) => Text(
                  money ? nairaCompact(v) : v.round().toString(),
                  style: TextStyle(fontSize: 11, color: AC.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 ||
                      i >= labels.length ||
                      i % step != 0 && i != labels.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[i],
                      style: TextStyle(fontSize: 11, color: AC.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AC.cardHigh,
              tooltipBorder: BorderSide(color: AC.border),
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${labels[s.x.toInt()]}\n${money ? nairaCompact(s.y) : s.y.round()}',
                    TextStyle(
                      color: s.bar.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            series(values, color),
            if (second != null) series(second!, secondColor, area: false),
          ],
        ),
      ),
    );
  }
}

/// Donut with a centre label and a legend.
class Donut extends StatelessWidget {
  const Donut({
    super.key,
    required this.items,
    required this.centreValue,
    required this.centreLabel,
  });

  final List<(String label, num value, Color color)> items;
  final String centreValue;
  final String centreLabel;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<num>(0, (a, b) => a + b.$2);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 54,
                  startDegreeOffset: -90,
                  sections: [
                    for (final i in items)
                      PieChartSectionData(
                        value: i.$2.toDouble() == 0 ? 0.0001 : i.$2.toDouble(),
                        color: i.$3,
                        radius: 20,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centreValue,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    centreLabel,
                    style: TextStyle(fontSize: 12, color: AC.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i.$3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          i.$1,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        total == 0 ? '0' : '${(i.$2 / total * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vertical bars (e.g. trips per hour).
class Bars extends StatelessWidget {
  const Bars({
    super.key,
    required this.values,
    required this.labels,
    this.color = AC.primary,
    this.height = 220,
    this.money = false,
  });

  final List<num> values;
  final List<String> labels;
  final Color color;
  final double height;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final maxY = values.isEmpty
        ? 1.0
        : max(1.0, values.reduce(max).toDouble() * 1.15);
    final step = max(1, (labels.length / 8).ceil());
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AC.border, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 4,
                getTitlesWidget: (v, _) => Text(
                  money ? nairaCompact(v) : v.round().toString(),
                  style: TextStyle(fontSize: 11, color: AC.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i % step != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(fontSize: 11, color: AC.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AC.cardHigh,
              getTooltipItem: (g, _, r, _) => BarTooltipItem(
                '${labels[g.x]}\n${money ? nairaCompact(r.toY) : r.toY.round()}',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: max(4, 220 / values.length),
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
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
