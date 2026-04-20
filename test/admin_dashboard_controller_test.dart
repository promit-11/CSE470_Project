import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cse470_app/controllers/providers.dart';
import 'test_helpers.dart';

void main() {
  group('AdminDashboardController', () {
    late ProviderContainer container;
    late MockAdminService mockService;

    setUp(() {
      mockService = MockAdminService();
      container = ProviderContainer(
        overrides: [adminServiceProvider.overrideWithValue(mockService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is correct', () {
      final state = container.read(adminDashboardControllerProvider);

      expect(state.isLoading, false);
      expect(state.errorMessage, null);
      expect(state.overview, null);
      expect(state.exams, isEmpty);
      expect(state.questions, isEmpty);
      expect(state.templates, isEmpty);
    });

    test('load fetches admin data', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();

      final state = container.read(adminDashboardControllerProvider);

      expect(state.isLoading, false);
      expect(state.overview, isNotNull);
      expect(state.exams, isNotEmpty);
      expect(state.questions, isNotEmpty);
      expect(state.templates, isNotEmpty);
      expect(mockService.callLog.contains('getOverview'), true);
    });

    test('load sets error on service failure', () async {
      mockService.shouldThrow = true;

      await container.read(adminDashboardControllerProvider.notifier).load();

      final state = container.read(adminDashboardControllerProvider);

      expect(state.isLoading, false);
      expect(state.errorMessage, isNotNull);
      expect(state.overview, null);
    });

    test('Overview data is properly populated', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();

      final state = container.read(adminDashboardControllerProvider);
      final overview = state.overview;

      expect(overview?['userCount'], 100);
      expect(overview?['studentCount'], 80);
      expect(overview?['instituteCount'], 5);
      expect(overview?['sessionsCompleted'], 250);
    });

    test('createQuestion with specified section', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();

      final payload = {
        'section': 'reading',
        'title': 'Reading Question 1',
        'category': 'passage_1',
        'difficulty': 'medium',
        'questionType': 'mcq',
        'content': 'Test content',
        'options': [
          {'key': 'A', 'text': 'Option A'},
          {'key': 'B', 'text': 'Option B'},
        ],
        'answerKey': ['A'],
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createQuestion(payload);

      expect(mockService.callLog.contains('createQuestion:reading'), true);
      expect(mockService.createdQuestions['Reading Question 1'], 'reading');
    });

    test('createQuestion with listening section', () async {
      final payload = {
        'section': 'listening',
        'title': 'Listening Question 1',
        'category': 'section_1',
        'difficulty': 'easy',
        'questionType': 'mcq',
        'content': 'Test content',
        'options': [],
        'answerKey': [],
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createQuestion(payload);

      expect(mockService.createdQuestions['Listening Question 1'], 'listening');
    });

    test('createQuestion with writing section', () async {
      final payload = {
        'section': 'writing',
        'title': 'Writing Task 1',
        'category': 'task_1',
        'difficulty': 'medium',
        'questionType': 'essay',
        'content': 'Write an essay about...',
        'options': [],
        'answerKey': [],
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createQuestion(payload);

      expect(mockService.createdQuestions['Writing Task 1'], 'writing');
    });

    test('createQuestion with speaking section', () async {
      final payload = {
        'section': 'speaking',
        'title': 'Speaking Part 1',
        'category': 'part_1',
        'difficulty': 'easy',
        'questionType': 'essay',
        'content': 'Talk about...',
        'options': [],
        'answerKey': [],
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createQuestion(payload);

      expect(mockService.createdQuestions['Speaking Part 1'], 'speaking');
    });

    test('createQuestion handles service error', () async {
      mockService.shouldThrow = true;

      try {
        await container
            .read(adminDashboardControllerProvider.notifier)
            .createQuestion({
              'section': 'reading',
              'title': 'Test',
              'category': 'test',
              'difficulty': 'medium',
              'questionType': 'mcq',
              'content': 'Test',
              'options': [],
              'answerKey': [],
            });
      } catch (e) {
        expect(e, isException);
      }
    });

    test('createQuestion allows all four section types', () async {
      final sections = ['listening', 'reading', 'writing', 'speaking'];

      for (final section in sections) {
        final payload = {
          'section': section,
          'title': 'Test Question for $section',
          'category': 'test',
          'difficulty': 'medium',
          'questionType': 'mcq',
          'content': 'Content',
          'options': [],
          'answerKey': [],
        };

        await container
            .read(adminDashboardControllerProvider.notifier)
            .createQuestion(payload);

        expect(
          mockService.createdQuestions.containsKey(
            'Test Question for $section',
          ),
          true,
        );
        expect(
          mockService.createdQuestions['Test Question for $section'],
          section,
        );
      }
    });

    test('createExam saves exam data', () async {
      final payload = {
        'title': 'Full Length Mock Test',
        'description': 'Complete mock exam',
        'type': 'academic',
        'active': true,
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createExam(payload);

      expect(mockService.callLog.contains('createExam'), true);
    });

    test('createTemplate saves template configuration', () async {
      final payload = {
        'name': 'Custom Template',
        'examType': 'academic',
        'sectionOrder': ['listening', 'reading', 'writing', 'speaking'],
        'difficultyDistribution': {'easy': 0.3, 'medium': 0.4, 'hard': 0.3},
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createTemplate(payload);

      expect(mockService.callLog.contains('createTemplate'), true);
    });

    test('Exams list contains exam data', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();

      final state = container.read(adminDashboardControllerProvider);

      expect(state.exams, isNotEmpty);
      expect(state.exams.first['id'], 'exam1');
      expect(state.exams.first['title'], 'Mock Exam 1');
    });

    test('Questions list contains question data', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();

      final state = container.read(adminDashboardControllerProvider);

      expect(state.questions, isNotEmpty);
      expect(state.questions.first['id'], 'q1');
      expect(state.questions.first['title'], 'Question 1');
    });

    test('Templates list contains template data', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();

      final state = container.read(adminDashboardControllerProvider);

      expect(state.templates, isNotEmpty);
      expect(state.templates.first['id'], 'template1');
      expect(state.templates.first['name'], 'Default Template');
      expect(state.templates.first['active'], true);
    });

    test('Error message is cleared on new load', () async {
      mockService.shouldThrow = true;
      await container.read(adminDashboardControllerProvider.notifier).load();

      var state = container.read(adminDashboardControllerProvider);
      expect(state.errorMessage, isNotNull);

      mockService.shouldThrow = false;
      await container.read(adminDashboardControllerProvider.notifier).load();

      state = container.read(adminDashboardControllerProvider);
      expect(state.errorMessage, null);
    });

    test('Multiple questions can be created sequentially', () async {
      final questions = [
        {
          'section': 'listening',
          'title': 'Q1',
          'category': 'cat1',
          'difficulty': 'easy',
          'questionType': 'mcq',
          'content': 'Content 1',
          'options': [],
          'answerKey': [],
        },
        {
          'section': 'reading',
          'title': 'Q2',
          'category': 'cat2',
          'difficulty': 'medium',
          'questionType': 'mcq',
          'content': 'Content 2',
          'options': [],
          'answerKey': [],
        },
      ];

      for (final q in questions) {
        await container
            .read(adminDashboardControllerProvider.notifier)
            .createQuestion(q);
      }

      expect(mockService.createdQuestions.length, 2);
      expect(mockService.createdQuestions['Q1'], 'listening');
      expect(mockService.createdQuestions['Q2'], 'reading');
    });

    test('Section selection persists in question payload', () async {
      final payload = {
        'section': 'writing',
        'title': 'Essay Task',
        'category': 'essay',
        'difficulty': 'medium',
        'questionType': 'essay',
        'content': 'Write about technology',
        'options': [],
        'answerKey': [],
      };

      await container
          .read(adminDashboardControllerProvider.notifier)
          .createQuestion(payload);

      // Verify the service received the correct section even after reload calls.
      expect(mockService.callLog.contains('createQuestion:writing'), true);
    });

    test('All question types are supported', () async {
      final questionTypes = ['mcq', 'essay', 'fill_blank'];

      for (final type in questionTypes) {
        final payload = {
          'section': 'reading',
          'title': 'Question $type',
          'category': 'test',
          'difficulty': 'medium',
          'questionType': type,
          'content': 'Test content',
          'options': [],
          'answerKey': [],
        };

        await container
            .read(adminDashboardControllerProvider.notifier)
            .createQuestion(payload);
      }

      expect(mockService.createdQuestions.length, 3);
    });

    test('Difficulty levels are properly handled', () async {
      final difficulties = ['easy', 'medium', 'hard'];

      for (final difficulty in difficulties) {
        final payload = {
          'section': 'reading',
          'title': 'Question $difficulty',
          'category': 'test',
          'difficulty': difficulty,
          'questionType': 'mcq',
          'content': 'Test',
          'options': [],
          'answerKey': [],
        };

        await container
            .read(adminDashboardControllerProvider.notifier)
            .createQuestion(payload);
      }

      expect(mockService.createdQuestions.length, 3);
    });

    test('Load is idempotent (can be called multiple times)', () async {
      await container.read(adminDashboardControllerProvider.notifier).load();
      final firstLoad = mockService.callLog.length;

      await container.read(adminDashboardControllerProvider.notifier).load();
      final secondLoad = mockService.callLog.length;

      // Should have same number of calls (minus the initial set)
      expect(secondLoad - firstLoad, firstLoad);
    });
  });
}
