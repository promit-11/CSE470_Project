import 'package:fl_chart/fl_chart.dart';
import 'package:cse470_app/models/dashboard_models.dart';
import 'package:flutter/material.dart';

class BandTrendChart extends StatelessWidget {
  const BandTrendChart({super.key, required this.trend});

  final List<TrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No trend data yet. Complete a mock test.')),
      );
    }

    final spots = <FlSpot>[];
    var skipped = 0;
    for (var i = 0; i < trend.length; i++) {
      final value = trend[i].overallBand;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      } else {
        skipped += 1;
      }
    }

    if (spots.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Overall band trend will appear after writing and speaking reviews are completed.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (skipped > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$skipped attempt(s) excluded until full subjective review is finalized.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
            ),
          ),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 9,
              gridData: const FlGridData(show: true),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
