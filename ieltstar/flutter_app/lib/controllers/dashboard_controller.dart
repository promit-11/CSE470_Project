import 'package:flutter/foundation.dart';

import '../models/result_model.dart';
import '../services/mock_test_service.dart';

class TrendPoint {
  const TrendPoint({
    required this.index,
    required this.score,
    required this.section,
    this.date,
  });

  final int index;
  final double score;
  final String section;
  final DateTime? date;
}

class FeedbackItem {
  const FeedbackItem({required this.title, required this.message});

  final String title;
  final String message;
}

class DashboardController extends ChangeNotifier {
  DashboardController({required MockTestService service}) : _service = service;

  final MockTestService _service;

  ResultModel? _studentResult;
  List<ResultModel> _history = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  ResultModel? get studentResult => _studentResult;
  List<ResultModel> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard(String studentEmail) async {
    _setLoading(true);
    _clearError();
    try {
      _studentResult = await _service.getResults(studentEmail: studentEmail);
      _history = _studentResult?.testHistory ?? <ResultModel>[];
      _hasLoaded = true;
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      _hasLoaded = true;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Map<String, double> get sectionAverages {
    final scores = <String, List<double>>{
      'Reading': <double>[],
      'Listening': <double>[],
      'Writing': <double>[],
      'Speaking': <double>[],
    };

    for (final entry in _history) {
      if (entry.testType == null || entry.score == null) {
        continue;
      }
      final score = _toDouble(entry.score);
      if (score == null) {
        continue;
      }
      final bucket = scores[entry.testType];
      if (bucket != null) {
        bucket.add(score);
      }
    }

    return scores.map((key, values) {
      if (values.isEmpty) {
        return MapEntry(key, 0);
      }
      final average = values.reduce((a, b) => a + b) / values.length;
      return MapEntry(key, average);
    });
  }

  Map<String, int> get sectionAttemptCounts {
    final attempts = <String, int>{
      'Reading': 0,
      'Listening': 0,
      'Writing': 0,
      'Speaking': 0,
    };

    for (final entry in _history) {
      final key = entry.testType;
      if (key != null && attempts.containsKey(key)) {
        attempts[key] = attempts[key]! + 1;
      }
    }

    return attempts;
  }

  int get totalAttempts => _history.length;

  List<TrendPoint> get scoreTrends {
    final numericEntries = _history
        .where(
            (entry) => entry.testType != null && _toDouble(entry.score) != null)
        .toList()
      ..sort((left, right) {
        final leftDate = left.date;
        final rightDate = right.date;
        if (leftDate == null && rightDate == null) {
          return 0;
        }
        if (leftDate == null) {
          return -1;
        }
        if (rightDate == null) {
          return 1;
        }
        return leftDate.compareTo(rightDate);
      });

    return List<TrendPoint>.generate(numericEntries.length, (index) {
      final entry = numericEntries[index];
      return TrendPoint(
        index: index,
        score: _toDouble(entry.score)!,
        section: entry.testType!,
        date: entry.date,
      );
    });
  }

  List<FeedbackItem> get feedback {
    final items = <FeedbackItem>[];
    final averages = sectionAverages;

    void addFeedbackForSection(String section) {
      final average = averages[section] ?? 0;
      final attempts = sectionAttemptCounts[section] ?? 0;

      if (attempts == 0) {
        items.add(
          FeedbackItem(
            title: '$section pending',
            message:
                'No attempts yet. Complete one $section section to unlock targeted feedback.',
          ),
        );
        return;
      }

      if (average >= 7.5) {
        items.add(
          FeedbackItem(
            title: '$section is strong',
            message:
                'Great consistency. Maintain timing discipline and review only high-impact mistakes.',
          ),
        );
      } else if (average >= 6.0) {
        items.add(
          FeedbackItem(
            title: '$section is improving',
            message:
                'You are in the target range. Focus on the question types where accuracy drops late in the section.',
          ),
        );
      } else {
        items.add(
          FeedbackItem(
            title: '$section needs attention',
            message:
                'Prioritize fundamentals and timed drills for this section before adding more full tests.',
          ),
        );
      }
    }

    addFeedbackForSection('Listening');
    addFeedbackForSection('Reading');
    addFeedbackForSection('Writing');
    addFeedbackForSection('Speaking');

    if (totalAttempts >= 4 && scoreTrends.length >= 2) {
      final first = scoreTrends.first.score;
      final last = scoreTrends.last.score;
      if (last - first >= 0.5) {
        items.insert(
          0,
          const FeedbackItem(
            title: 'Positive momentum',
            message:
                'Your recent scores are trending upward. Keep your current revision rhythm.',
          ),
        );
      } else if (first - last >= 0.5) {
        items.insert(
          0,
          const FeedbackItem(
            title: 'Trend alert',
            message:
                'Recent scores dipped compared with earlier tests. Revisit weak areas before the next full mock.',
          ),
        );
      }
    }

    return items;
  }

  double get overallAverage {
    final averages =
        sectionAverages.values.where((value) => value > 0).toList();
    if (averages.isEmpty) {
      return 0;
    }
    final overall = averages.reduce((a, b) => a + b) / averages.length;
    return double.parse(overall.toStringAsFixed(1));
  }

  void clear() {
    _studentResult = null;
    _history = [];
    _errorMessage = null;
    _isLoading = false;
    _hasLoaded = false;
    notifyListeners();
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
