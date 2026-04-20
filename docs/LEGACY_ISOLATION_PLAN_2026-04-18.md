# Legacy Isolation Plan (Safe, No Deletion)

Date: 2026-04-18
Scope: Isolate old non-V1 stack without breaking active runtime

## Active runtime path (source of truth)

Backend:
- api/app.js -> api/routes/index.js -> /api/v1 -> api/routes/v1/index.js
- Mounted V1 modules: auth, students, institutes, admin, mock-sessions, analytics

Frontend:
- main.dart -> AppRouter -> active screens
- providers.dart wires active controllers/services:
  - AuthController/AuthService
  - StudentDashboardController/StudentService
  - StudentArchiveController/StudentService
  - ExamSessionController/MockService
  - InstituteController/InstituteService
  - AdminDashboardController/AdminService

## Safe-to-deprecate files (not used by active runtime path)

### Frontend legacy stack
- lib/models/test_model.dart
- lib/models/test_history.dart
- lib/services/test_service.dart
- lib/services/exam_service.dart
- lib/controllers/admin_test_controller.dart
- lib/controllers/admin_exam_controller.dart
- lib/routes/route_args.dart

Reason:
- They target old /tests and /exams endpoints and are not wired through providers.dart or AppRouter active screens.

### Backend legacy route entries (not mounted)
- lib/website_version/server/api/routes/test-router.js
- lib/website_version/server/api/routes/exam-router.js
- lib/website_version/server/api/routes/student-router.js
- lib/website_version/server/api/routes/score-router.js

Reason:
- api/routes/index.js mounts only /api/v1.

### Backend legacy services/controllers/models (only used by legacy routers)
Services:
- lib/website_version/server/api/services/test-service.js
- lib/website_version/server/api/services/exam-service.js
- lib/website_version/server/api/services/student-service.js
- lib/website_version/server/api/services/score-service.js
- lib/website_version/server/api/services/questions-service.js

Controllers:
- lib/website_version/server/api/controllers/test-controller.js
- lib/website_version/server/api/controllers/exam-controller.js
- lib/website_version/server/api/controllers/student-controller.js
- lib/website_version/server/api/controllers/score-controller.js
- lib/website_version/server/api/controllers/questions-controller.js

Models:
- lib/website_version/server/api/models/Test.js
- lib/website_version/server/api/models/Exam.js
- lib/website_version/server/api/models/Student.js
- lib/website_version/server/api/models/TestHistory.js
- lib/website_version/server/api/models/Question.js
- lib/website_version/server/api/models/score.js
- lib/website_version/server/api/models/index.js

## Files still referenced (do not remove)

### Frontend active
- lib/main.dart
- lib/routes/app_routes.dart
- lib/routes/app_router.dart
- lib/controllers/providers.dart
- lib/controllers/auth_controller.dart
- lib/controllers/student_dashboard_controller.dart
- lib/controllers/student_archive_controller.dart
- lib/controllers/exam_session_controller.dart
- lib/controllers/institute_controller.dart
- lib/controllers/admin_dashboard_controller.dart
- lib/services/api_client.dart
- lib/services/auth_service.dart
- lib/services/student_service.dart
- lib/services/mock_service.dart
- lib/services/institute_service.dart
- lib/services/admin_service.dart
- lib/views/screens/splash_screen.dart
- lib/views/screens/login_screen.dart
- lib/views/screens/register_screen.dart
- lib/views/screens/student_dashboard_screen.dart
- lib/views/screens/student_archive_screen.dart
- lib/views/screens/exam_session_screen.dart
- lib/views/screens/result_summary_screen.dart
- lib/views/screens/institute_dashboard_screen.dart
- lib/views/screens/admin_exam_list_screen.dart

### Backend active
- lib/website_version/server/api/app.js
- lib/website_version/server/api/routes/index.js
- lib/website_version/server/api/routes/v1/index.js
- lib/website_version/server/api/routes/v1/auth-routes.js
- lib/website_version/server/api/routes/v1/student-routes.js
- lib/website_version/server/api/routes/v1/institute-routes.js
- lib/website_version/server/api/routes/v1/admin-routes.js
- lib/website_version/server/api/routes/v1/mock-routes.js
- lib/website_version/server/api/routes/v1/analytics-routes.js
- lib/website_version/server/api/services/v1/*
- lib/website_version/server/api/models/v1/*
- lib/website_version/server/api/constants/*
- lib/website_version/server/api/middlewares/*
- lib/website_version/server/api/utils/*
- lib/website_version/server/api/validators/*

## Dangerous dependencies to handle manually before removal

1. Legacy frontend model ties:
- route_args.dart references TestModel.
- If deleting test_model.dart, route_args.dart must be removed or rewritten.

2. Legacy backend chain dependencies:
- Legacy routes -> legacy controllers -> legacy services -> legacy models.
- Delete as a single chain, not piecemeal, to avoid broken imports.

3. Potential external/manual usage:
- Developers may still call legacy endpoints directly in local scripts/Postman.
- Before final removal, communicate endpoint deprecation and cutover to /api/v1.

4. Data/schema transition risk:
- Legacy models now include deprecation and partial compatibility updates.
- If any historical data exists in old collections, archive/export before removing models.

## Suggested final cleanup actions (safe sequence)

1. Freeze and document active architecture (this doc + implementation audit).
2. Keep deprecation comments in legacy files for one release cycle.
3. Add CI lint rule or static check to block new imports from legacy frontend files.
4. Add tests for active V1 flows (mock-sessions, admin question create, student analytics).
5. Remove legacy backend routes/controllers/services/models in a single PR.
6. Remove legacy frontend models/services/controllers/route args in a follow-up PR.
7. Re-run full smoke test and API contract verification after each PR.
