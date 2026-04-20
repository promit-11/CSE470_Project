import 'package:cse470_app/views/screens/teacher_pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Active Widget Tests - Real screen rendering and UI verification
/// Tests actual widget rendering for active runtime with real parameters

void main() {
  group('Active Widget Tests - Teacher Pending Approval Screen', () {
    testWidgets('Renders pending approval message with email parameter', (
      WidgetTester tester,
    ) async {
      const testEmail = 'newteacher@institution.edu';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherPendingApprovalScreen(email: testEmail),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Core UI elements verification
      expect(find.text('Teacher Account Under Review'), findsOneWidget);
      expect(find.textContaining('pending'), findsWidgets);
      expect(find.text('Back To Login'), findsOneWidget);
    });

    testWidgets('Renders scaffold with app bar and navigation structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherPendingApprovalScreen(email: 'test@example.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify scaffold and app bar
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Approval Pending'), findsOneWidget);
    });

    testWidgets('Renders with material design layout widgets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherPendingApprovalScreen(email: 'widget@test.local'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify material design elements
      expect(find.byType(Center), findsWidgets);
      expect(find.byType(Padding), findsWidgets);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Text), findsWidgets);
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('Renders correctly with empty email parameter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TeacherPendingApprovalScreen(email: '')),
        ),
      );

      await tester.pumpAndSettle();

      // Screen should render without email
      expect(find.text('Teacher Account Under Review'), findsOneWidget);
      expect(find.text('Back To Login'), findsOneWidget);
    });

    testWidgets('Displays approval message with key phrases', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherPendingApprovalScreen(email: 'approval@test.local'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify key message components
      expect(find.textContaining('Account'), findsWidgets);
      expect(find.textContaining('approval'), findsWidgets);
      expect(find.textContaining('sign in'), findsWidgets);
    });

    testWidgets('Uses responsive layout with constraints', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherPendingApprovalScreen(email: 'layout@test.local'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify constraint box for responsive layout
      expect(find.byType(ConstrainedBox), findsWidgets);
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('Displays back navigation button for routing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherPendingApprovalScreen(email: 'navigate@test.local'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify back navigation button exists
      expect(find.text('Back To Login'), findsOneWidget);
    });

    testWidgets('Handles multiple email format variations', (
      WidgetTester tester,
    ) async {
      const emails = [
        'teacher1@school.edu',
        'instructor@university.org',
        'prof@college.ac.uk',
      ];

      for (final email in emails) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: TeacherPendingApprovalScreen(email: email),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Each variant should render the title
        expect(find.text('Teacher Account Under Review'), findsOneWidget);

        // Each variant should have navigation button
        expect(find.text('Back To Login'), findsOneWidget);
      }
    });
  });
}
