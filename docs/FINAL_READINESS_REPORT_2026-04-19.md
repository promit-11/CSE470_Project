# Final Readiness Report

## Scope
This pass traced the current architecture across the four live role paths and the operational workflows around ownership, review, approval, and payouts.

## Verified End-to-End Role Flows

### Independent student
- Routes from splash/login to the student dashboard.
- Can start or restore sessions, view archive/history, and see pending vs reviewed writing/speaking states.
- Uses app-owned test/session data with auto-scored listening/reading and teacher-reviewed writing/speaking.

### Coaching student
- Routes to the student coaching assignment workflow.
- Loads the coaching assignment form, submits a request, and surfaces pending-request state.
- This path is isolated from the core test flow and remains the correct entry point for coaching assignment requests.

### Teacher
- Routes to teacher dashboard or teacher pending approval depending on approval status.
- Handles pending, claimed, and reviewed evaluation queues.
- Can submit reviews and request payout from accumulated reward credits.

### Coaching admin
- Routes to the coaching dashboard alias, currently implemented in the legacy-named institute dashboard screen.
- Manages coaching profile data, assignment requests, coaching-owned content, and related queue actions.
- This path remains active and is the correct home for coaching_admin users.

### Platform admin
- Routes from splash/login to the platform admin exam dashboard.
- Manages app-owned exams/questions/templates, teacher approvals, payout reviews, and evaluation totals.
- This is the current platform_admin entry point.

## Legacy Paths Isolated or Deprecated
These paths are still present for compatibility, but they are not part of the live AppRouter V1 flow.

- [lib/controllers/admin_test_controller.dart](../lib/controllers/admin_test_controller.dart)
- [lib/controllers/admin_exam_controller.dart](../lib/controllers/admin_exam_controller.dart)
- [lib/services/test_service.dart](../lib/services/test_service.dart)
- [lib/services/exam_service.dart](../lib/services/exam_service.dart)
- [lib/models/test_model.dart](../lib/models/test_model.dart)
- [lib/models/test_history.dart](../lib/models/test_history.dart)
- [lib/routes/route_args.dart](../lib/routes/route_args.dart)
- [lib/models/student.dart](../lib/models/student.dart)

Current isolation approach:
- Deprecated files are kept in place to avoid risky deletions.
- Comments identify them as legacy-only.
- Live routes use [lib/routes/app_router.dart](../lib/routes/app_router.dart) and the newer service/controller stack.

## Remaining Technical Debt
- `InstituteDashboardScreen` still uses legacy naming in the file path and some UI labels. Behavior is correct, but naming is not yet harmonized.
- Legacy controllers/services remain in the tree as compatibility shims and should be removed only after no references remain.
- Some admin/institute terminology still exists in UI copy and model naming, even though the live flows are now role-based.

## Manual Test Scenarios
1. Student login as a plain student, start a mock test, complete it, and confirm listening/reading are immediate while writing/speaking show pending review.
2. Student with coaching assignment access the request form, submit a coaching center request, and confirm pending status persists.
3. Teacher login with pending approval and confirm routing to the approval screen; then verify approved teachers reach the dashboard.
4. Teacher claim a pending evaluation, submit a review, and verify payout request UI reflects reward credits.
5. Coaching admin login and confirm coaching dashboard routing, assignment queue visibility, and coaching-owned management sections.
6. Platform admin login and confirm the app-owned exam dashboard, teacher approval queue, and payout review queue load correctly.

## Demo Flow Order
1. Splash screen role routing.
2. Student dashboard.
3. Coaching assignment request workflow.
4. Teacher approval and review workflow.
5. Teacher payout request flow.
6. Coaching admin dashboard and queues.
7. Platform admin dashboard and approval/payout queues.
8. Student archive and result summary with pending/reviewed states.

## Validation Status
- Analyzer: clean.
- Tests: last full run passed 78/78.
