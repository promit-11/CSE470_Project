import 'package:flutter/material.dart';

class SectionScoreCard extends StatelessWidget {
  const SectionScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.color,
  });

  final String title;
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.analytics, color: color),
                const SizedBox(width: 8),
                Text(
                  score.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
