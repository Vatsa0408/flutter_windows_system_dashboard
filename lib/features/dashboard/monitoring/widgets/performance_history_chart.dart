import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../system_metrics.dart';

class PerformanceHistoryChart extends StatelessWidget {
  const PerformanceHistoryChart({
    super.key,
    required this.title,
    required this.history,
    required this.valueSelector,
    required this.lineColor,
    required this.average,
    required this.maximum,
  });

  final String title;
  final List<SystemMetrics> history;
  final double Function(SystemMetrics metrics) valueSelector;
  final Color lineColor;
  final double average;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final textColor = theme.typography.body?.color ?? Colors.white;
    final borderColor = theme.resources.dividerStrokeColorDefault;
    final spots = <FlSpot>[
      for (var index = 0; index < history.length; index++)
        FlSpot(index.toDouble(), valueSelector(history[index])),
    ];

    return Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.typography.subtitle,
                ),
              ),
              _Statistic(label: 'Average', value: average),
              const SizedBox(width: 18),
              _Statistic(label: 'Maximum', value: maximum),
            ],
          ),
          const SizedBox(height: 18),
          if (spots.length < 2)
            const SizedBox(
              height: 220,
              child: Center(
                child: Text('Collecting samples for the chart...'),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: borderColor,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: borderColor),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: 25,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.round()}%',
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (spot) => LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)}%',
                              TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      preventCurveOverShooting: true,
                      color: lineColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${history.length} samples, newest sample on the right',
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: FluentTheme.of(context).typography.caption),
        Text(
          '${value.toStringAsFixed(1)}%',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
      ],
    );
  }
}
