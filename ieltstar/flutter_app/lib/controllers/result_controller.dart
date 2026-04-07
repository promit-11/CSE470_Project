import 'package:flutter/foundation.dart';

import '../models/result_model.dart';
import '../services/mock_test_service.dart';

class SectionScoreSummary {
  const SectionScoreSummary({
    required this.section,
    required this.rawScore,
    required this.bandScore,
  });

  final String section;
  final double? rawScore;
  final double? bandScore;
}

class ResultController extends ChangeNotifier {
  ResultController({required MockTestService service}) : _service = service;

  final MockTestService _service;

  ResultModel? _currentResult;
  List<ResultModel> _testHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  ResultModel? get currentResult => _currentResult;
  List<ResultModel> get testHistory => List.unmodifiable(_testHistory);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<SectionScoreSummary> get sectionSummaries {
    final result = _currentResult;
    if (result == null) {
      return const [];
    }

    return [
      _buildSectionSummary(
        section: 'Listening',
        score: result.listeningScore ?? _latestHistoryScore('Listening'),
      ),
      _buildSectionSummary(
        section: 'Reading',
        score: result.readingScore ?? _latestHistoryScore('Reading'),
      ),
      _buildSectionSummary(
        section: 'Writing',
        score: result.writingScore ?? _latestHistoryScore('Writing'),
      ),
      _buildSectionSummary(
        section: 'Speaking',
        score: result.speakingScore ?? _latestHistoryScore('Speaking'),
      ),
    ];
  }

  double? get overallBandScore {
    final result = _currentResult;
    if (result == null) {
      return null;
    }

    final explicitOverallBand = _normalizeBand(result.overallBand);
    if (explicitOverallBand != null) {
      return explicitOverallBand;
    }

    final sectionBands = sectionSummaries
        .map((summary) => summary.bandScore)
        .whereType<double>()
        .toList();

    if (sectionBands.isEmpty) {
      return null;
    }

    final average = sectionBands.reduce((left, right) => left + right) /
        sectionBands.length;
    return _roundToNearestHalf(average);
  }

  double? get listeningBandScore => _summaryBandForSection(
        'Listening',
        _currentResult?.listeningScore ?? _latestHistoryScore('Listening'),
      );

  double? get readingBandScore => _summaryBandForSection(
        'Reading',
        _currentResult?.readingScore ?? _latestHistoryScore('Reading'),
      );

  double? get writingBandScore => _summaryBandForSection(
        'Writing',
        _currentResult?.writingScore ?? _latestHistoryScore('Writing'),
      );

  double? get speakingBandScore => _summaryBandForSection(
        'Speaking',
        _currentResult?.speakingScore ?? _latestHistoryScore('Speaking'),
      );

  double convertRawScoreToBand({
    required String section,
    required int rawScoreOn40,
  }) {
    if (section == 'Listening' || section == 'Reading') {
      return _bandFromRawScore(rawScoreOn40.toDouble());
    }

    return _roundToNearestHalf(rawScoreOn40.toDouble());
  }

  double calculateOverallBandFromSections({
    required double listeningBand,
    required double readingBand,
    required double writingBand,
    required double speakingBand,
  }) {
    final average =
        (listeningBand + readingBand + writingBand + speakingBand) / 4;
    return _roundToNearestHalf(average);
  }

  Future<void> loadResults(String studentEmail) async {
    _setLoading(true);
    _clearError();
    try {
      _currentResult = await _service.getResults(studentEmail: studentEmail);
      _testHistory = _currentResult?.testHistory ?? <ResultModel>[];
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshHistory(String studentEmail) async {
    _setLoading(true);
    _clearError();
    try {
      _testHistory = await _service.getTestHistory(studentEmail: studentEmail);
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clear() {
    _currentResult = null;
    _testHistory = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  SectionScoreSummary _buildSectionSummary({
    required String section,
    required num? score,
  }) {
    return SectionScoreSummary(
      section: section,
      rawScore: score?.toDouble(),
      bandScore: _summaryBandForSection(section, score),
    );
  }

  double? _summaryBandForSection(String section, num? score) {
    final value = _normalizeBand(score);
    if (value == null) {
      return null;
    }

    if (section == 'Listening' || section == 'Reading') {
      return _roundToNearestHalf(value);
    }

    return _roundToNearestHalf(value);
  }

  double? _normalizeBand(num? score) {
    if (score == null) {
      return null;
    }

    return score.toDouble();
  }

  num? _latestHistoryScore(String section) {
    final history = _currentResult?.testHistory;
    if (history == null || history.isEmpty) {
      return null;
    }

    final sectionAttempts = history
        .where((entry) => entry.testType == section && entry.score != null)
        .toList()
      ..sort((left, right) {
        final leftDate = left.date;
        final rightDate = right.date;
        if (leftDate == null && rightDate == null) {
          return 0;
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }
        return rightDate.compareTo(leftDate);
      });

    return sectionAttempts.isEmpty ? null : sectionAttempts.first.score;
  }

  double _bandFromRawScore(double rawScoreOn40) {
    if (rawScoreOn40 >= 39) return 9;
    if (rawScoreOn40 >= 37) return 8.5;
    if (rawScoreOn40 >= 35) return 8;
    if (rawScoreOn40 >= 33) return 7.5;
    if (rawScoreOn40 >= 30) return 7;
    if (rawScoreOn40 >= 27) return 6.5;
    if (rawScoreOn40 >= 23) return 6;
    if (rawScoreOn40 >= 19) return 5.5;
    if (rawScoreOn40 >= 15) return 5;
    if (rawScoreOn40 >= 13) return 4.5;
    return 4;
  }

  double _roundToNearestHalf(double score) {
    return (score * 2).roundToDouble() / 2;
  }
}
