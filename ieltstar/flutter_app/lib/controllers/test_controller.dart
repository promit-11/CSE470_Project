import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/answer_model.dart';
import '../models/question_model.dart';
import '../models/result_model.dart';
import '../models/test_model.dart';
import '../services/mock_test_service.dart';

class TestController extends ChangeNotifier {
  TestController({required MockTestService service}) : _service = service;

  final MockTestService _service;

  static const Map<String, Duration> _sectionDurations = {
    'Listening': Duration(minutes: 30),
    'Reading': Duration(minutes: 60),
    'Writing': Duration(minutes: 60),
    'Speaking': Duration(minutes: 15),
  };

  final List<TestModel> _sections = [];
  final Map<String, Map<String, String>> _selectedAnswersByTestId = {};
  final Map<String, Set<String>> _markedForReviewByTestId = {};
  final Map<String, List<Map<String, dynamic>>> _evaluationByTestId = {};

  Timer? _timer;
  String? _examId;
  String? _studentEmail;
  int _currentSectionIndex = 0;
  int _currentQuestionIndex = 0;
  Duration _remainingTime = Duration.zero;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _didAutoSubmit = false;
  String? _errorMessage;
  ResultModel? _lastSubmissionResult;

  List<TestModel> get sections => List.unmodifiable(_sections);
  TestModel? get currentSection =>
      _sections.isEmpty ? null : _sections[_currentSectionIndex];
  QuestionModel? get currentQuestion {
    final section = currentSection;
    if (section == null || section.questions.isEmpty) {
      return null;
    }
    if (_currentQuestionIndex < 0 ||
        _currentQuestionIndex >= section.questions.length) {
      return null;
    }
    return section.questions[_currentQuestionIndex];
  }

  String? get studentEmail => _studentEmail;
  String? get examId => _examId;
  int get currentSectionIndex => _currentSectionIndex;
  int get currentQuestionIndex => _currentQuestionIndex;
  Duration get remainingTime => _remainingTime;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get didAutoSubmit => _didAutoSubmit;
  String? get errorMessage => _errorMessage;
  ResultModel? get lastSubmissionResult => _lastSubmissionResult;

  Map<String, String> get selectedAnswersForCurrentSection {
    final section = currentSection;
    if (section == null) {
      return const {};
    }
    return Map.unmodifiable(_selectedAnswersByTestId[section.id] ?? {});
  }

  Set<String> get markedForReviewForCurrentSection {
    final section = currentSection;
    if (section == null) {
      return const {};
    }
    return Set.unmodifiable(_markedForReviewByTestId[section.id] ?? <String>{});
  }

  List<Map<String, dynamic>> get evaluationForCurrentSection {
    final section = currentSection;
    if (section == null) {
      return const [];
    }
    return List.unmodifiable(_evaluationByTestId[section.id] ?? const []);
  }

  Future<void> loadMockTest({
    required String examId,
    required String studentEmail,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      _examId = examId;
      _studentEmail = studentEmail;
      final loadedSections = await _service.fetchMockTest(examId: examId);
      _sections
        ..clear()
        ..addAll(_sortSections(loadedSections));
      _currentSectionIndex = 0;
      _currentQuestionIndex = 0;
      _didAutoSubmit = false;
      _lastSubmissionResult = null;
      _startTimerForCurrentSection();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void goToQuestion(int index) {
    final section = currentSection;
    if (section == null || index < 0 || index >= section.questions.length) {
      return;
    }
    _currentQuestionIndex = index;
    notifyListeners();
  }

  void nextQuestion() {
    goToQuestion(_currentQuestionIndex + 1);
  }

  void previousQuestion() {
    goToQuestion(_currentQuestionIndex - 1);
  }

  void selectAnswer({
    required String questionId,
    required String selectedOption,
  }) {
    final section = currentSection;
    if (section == null) {
      return;
    }

    final testId = section.id;
    if (testId == null) {
      return;
    }

    final sectionAnswers = _selectedAnswersByTestId.putIfAbsent(
      testId,
      () => <String, String>{},
    );
    sectionAnswers[questionId] = selectedOption;
    notifyListeners();
  }

  void toggleReviewFlag(String questionId) {
    final section = currentSection;
    if (section == null || section.id == null) {
      return;
    }

    final reviewSet = _markedForReviewByTestId.putIfAbsent(
      section.id!,
      () => <String>{},
    );
    if (reviewSet.contains(questionId)) {
      reviewSet.remove(questionId);
    } else {
      reviewSet.add(questionId);
    }
    notifyListeners();
  }

  void storeEvaluation(List<Map<String, dynamic>> evaluation) {
    final section = currentSection;
    if (section == null || section.id == null) {
      return;
    }

    _evaluationByTestId[section.id!] = evaluation;
    notifyListeners();
  }

  void nextSection() {
    if (_currentSectionIndex >= _sections.length - 1) {
      return;
    }

    _currentSectionIndex++;
    _currentQuestionIndex = 0;
    _startTimerForCurrentSection();
    notifyListeners();
  }

  void previousSection() {
    if (_currentSectionIndex <= 0) {
      return;
    }

    _currentSectionIndex--;
    _currentQuestionIndex = 0;
    _startTimerForCurrentSection();
    notifyListeners();
  }

  Future<ResultModel?> submitCurrentSection({bool autoSubmit = false}) async {
    final section = currentSection;
    final testId = section?.id;
    final studentEmail = _studentEmail;

    if (section == null || testId == null || studentEmail == null) {
      return null;
    }

    if (_isSubmitting) {
      return _lastSubmissionResult;
    }

    _setSubmitting(true);
    _clearError();

    try {
      final submission = _buildSubmission(section);
      final result = await _service.submitAnswers(
        studentEmail: studentEmail,
        submission: submission,
      );
      _lastSubmissionResult = result;
      _didAutoSubmit = autoSubmit;

      if (_currentSectionIndex < _sections.length - 1) {
        _currentSectionIndex++;
        _currentQuestionIndex = 0;
        _startTimerForCurrentSection();
      } else {
        _stopTimer();
      }

      notifyListeners();
      return result;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setSubmitting(false);
    }
  }

  void resetSession() {
    _stopTimer();
    _sections.clear();
    _selectedAnswersByTestId.clear();
    _markedForReviewByTestId.clear();
    _evaluationByTestId.clear();
    _examId = null;
    _studentEmail = null;
    _currentSectionIndex = 0;
    _currentQuestionIndex = 0;
    _remainingTime = Duration.zero;
    _didAutoSubmit = false;
    _errorMessage = null;
    _lastSubmissionResult = null;
    notifyListeners();
  }

  AnswerModel _buildSubmission(TestModel section) {
    final testId = section.id ?? '';
    final selectedAnswers = _selectedAnswersByTestId[testId] ?? const {};

    if (section.category == 'Listening' || section.category == 'Reading') {
      return AnswerModel(
        testType: section.category,
        testId: testId,
        examId: section.examId,
        section: section.section,
        score: 0,
        userResponse: section.questions.map((question) {
          final selectedAnswer = selectedAnswers[question.id ?? ''];
          return <String, dynamic>{
            'questionId': question.id,
            'questionOptions': question.options
                .map(
                  (option) => <String, dynamic>{
                    'que_options': option,
                    'selected': option == selectedAnswer,
                  },
                )
                .toList(),
          };
        }).toList(),
      );
    }

    return AnswerModel(
      testType: section.category,
      testId: testId,
      examId: section.examId,
      section: section.section,
      score: _evaluationByTestId[testId] ?? const [],
      userResponse: const [],
    );
  }

  List<TestModel> _sortSections(List<TestModel> sections) {
    final sorted = List<TestModel>.from(sections);
    sorted.sort((left, right) {
      final leftOrder = _categoryOrder(left.category);
      final rightOrder = _categoryOrder(right.category);
      final categoryComparison = leftOrder.compareTo(rightOrder);
      if (categoryComparison != 0) {
        return categoryComparison;
      }
      return left.section.compareTo(right.section);
    });
    return sorted;
  }

  int _categoryOrder(String category) {
    switch (category) {
      case 'Listening':
        return 0;
      case 'Reading':
        return 1;
      case 'Writing':
        return 2;
      case 'Speaking':
        return 3;
      default:
        return 99;
    }
  }

  void _startTimerForCurrentSection() {
    final section = currentSection;
    if (section == null) {
      _remainingTime = Duration.zero;
      _stopTimer();
      notifyListeners();
      return;
    }

    _stopTimer();
    _remainingTime = _sectionDurations[section.category] ?? Duration.zero;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 1) {
        _remainingTime = Duration.zero;
        timer.cancel();
        notifyListeners();
        if (!_isSubmitting) {
          unawaited(submitCurrentSection(autoSubmit: true));
        }
        return;
      }

      _remainingTime = _remainingTime - const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
