// DEPRECATED (legacy flow): Argument objects for old exam/test screen routing.
// Not used by the active AppRouter V1 screen flow.
import 'package:cse470_app/models/exam.dart';
import 'package:cse470_app/models/test_model.dart';

class ExamSessionArgs {
  const ExamSessionArgs({required this.exam});

  final Exam exam;
}

class AdminExamTestsArgs {
  const AdminExamTestsArgs({required this.exam});

  final Exam exam;
}

class AdminTestQuestionsArgs {
  const AdminTestQuestionsArgs({required this.test});

  final TestModel test;
}
