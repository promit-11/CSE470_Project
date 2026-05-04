double roundToBandStep(num value) {
  return ((value * 2).round() / 2).toDouble();
}

Map<String, double> averageByType(List<dynamic> history) {
  final sums = <String, double>{
    'Reading': 0,
    'Listening': 0,
    'Writing': 0,
    'Speaking': 0,
  };
  final counts = <String, int>{
    'Reading': 0,
    'Listening': 0,
    'Writing': 0,
    'Speaking': 0,
  };

  for (final item in history) {
    final type = item.testType;
    if (sums.containsKey(type)) {
      sums[type] = sums[type]! + item.score;
      counts[type] = counts[type]! + 1;
    }
  }

  return sums.map((key, value) {
    final count = counts[key] == 0 ? 1 : counts[key]!;
    return MapEntry(key, roundToBandStep(value / count));
  });
}
