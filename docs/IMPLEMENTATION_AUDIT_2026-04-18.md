# Implementation Audit and Functional Documentation

Date: 2026-04-18
Workspace: h:/CSE470_Project/cse470_app

## 1) Executive Summary

This project is a Flutter frontend with a Node/Express backend (MongoDB).

Current behavior:
- The active product flow is the V1 API stack under /api/v1.
- The app supports full mock session flow with sections: listening, reading, writing, speaking.
- Listening and reading are auto-scored (raw score to band conversion).
- Writing and speaking responses are stored, but no real scoring is implemented (band remains 0 unless manually handled later).

Main lags found:
- Legacy frontend files still use old integer section format (1,2,3...) and old endpoints (/tests, /exams).
- Active backend uses string section format (listening/reading/writing/speaking).
- Admin question creation UI hardcodes section as reading.
- Test coverage is minimal (1 Flutter widget test + 1 backend smoke-style test file).

## 2) Active Architecture

### Frontend
- Entry and app shell:
  - lib/main.dart
  - lib/routes/app_router.dart
  - lib/routes/app_routes.dart
- State management:
  - lib/controllers/providers.dart
  - Riverpod controllers for auth, student dashboard, archive, exam session, institute, admin dashboard
- API layer:
  - lib/services/api_client.dart
  - service classes for auth/student/mock/institute/admin

### Backend
- Active router mount:
  - lib/website_version/server/api/routes/index.js mounts only /api/v1
- V1 routes:
  - auth, students, institutes, admin, mock-sessions, analytics
- Core mock engine:
  - lib/website_version/server/api/services/v1/mock-service.js
  - lib/website_version/server/api/utils/mock-generator.js
  - lib/website_version/server/api/constants/sections.js

## 3) IELTS Section Coverage (Actual Behavior)

### Listening
- Included in section order and generation.
- Duration enforced as 30 minutes.
- Auto-scored by objective answer matching.
- Raw score converted to IELTS band.

### Reading
- Included in section order and generation.
- Duration enforced as 60 minutes.
- Auto-scored by objective answer matching.
- Raw score converted to IELTS band.

### Writing
- Included in section order and generation.
- Duration enforced as 60 minutes.
- Text responses are accepted and stored.
- No implemented scoring rubric in backend (band is set to 0 in current logic).

### Speaking
- Included in section order and generation.
- Duration enforced as 15 minutes.
- Text responses are accepted and stored.
- No implemented scoring rubric in backend (band is set to 0 in current logic).

## 4) Why It May Look Like "Only One Type"

You are not wrong to feel section-limited in parts of code.

Root causes:
1. Old/legacy frontend test files still use integer section and old endpoints.
2. Active admin exam list UI creates new questions with hardcoded section = reading.
3. Writing and speaking scoring is not implemented, so their outcomes look weak/zero.

This creates the impression that only one section is effectively working, even though the active mock-session engine supports all 4.

## 5) Requirement-Level Status

### Requirement 1: Full IELTS mock test flow
- Status: Mostly implemented.
- Works: section order, timer UI, question navigation, mark-for-review, submit section, final submit.
- Lag: timer restoration is simplistic; no robust server-driven remaining-time sync.

### Requirement 2: Estimated band score after test
- Status: Partial.
- Works: listening/reading objective scoring, raw-to-band conversion, overall summary rendering.
- Lag: writing/speaking scoring is missing.

### Requirement 3: Progress tracking
- Status: Implemented.
- Works: history, analytics payload, trend chart, strengths/weaknesses display, section feedback rendering.

### Requirement 4: Coaching center collaboration
- Status: Implemented with basic UI.
- Works: institute profile, verify student, create discount codes, auto apply discount on purchase.
- Lag: UX depth is limited.

### Requirement 5: Dynamic test generation
- Status: Backend implemented, frontend admin controls partial.
- Works: categorized question bank, random generation, section structure, difficulty distribution, repetition cap.
- Lag: frontend does not fully expose template tuning controls.

## 6) Prioritized Lag List

### Critical
1. Section type mismatch across frontend files (int section) vs active backend (string section).
2. Writing/speaking scoring not implemented (bands default to 0 in active scoring path).
3. Hardcoded reading section in admin create-question UI.

### High
4. Legacy backend files remain in repo and can mislead development.
5. Legacy frontend controllers/services for /tests and /exams are inconsistent with active V1 API.

### Medium
6. Very low automated test coverage.
7. Weak timer/session resume precision from backend elapsed-time perspective.

## 7) Full File Inventory and Role Notes

### Flutter files (lib/**/*.dart)

#### App + routes
- lib/main.dart: App bootstrap, theme, router wiring.
- lib/routes/app_router.dart: Route switch and screen mapping.
- lib/routes/app_routes.dart: Named route constants.
- lib/routes/route_args.dart: Route argument classes.

#### Models
- lib/models/app_user.dart: User role model.
- lib/models/auth_models.dart: Auth session and user role mapping.
- lib/models/dashboard_models.dart: Student analytics model.
- lib/models/exam.dart: Exam model.
- lib/models/mock_models.dart: Active mock session model set (string section).
- lib/models/question.dart: Generic question model.
- lib/models/student.dart: Student model.
- lib/models/test_history.dart: Legacy-style history model (int section).
- lib/models/test_model.dart: Legacy-style test model (int section).

#### Controllers
- lib/controllers/admin_dashboard_controller.dart: Active admin dashboard controller.
- lib/controllers/admin_exam_controller.dart: Legacy/auxiliary exam admin controller.
- lib/controllers/admin_test_controller.dart: Legacy/auxiliary test controller (int section).
- lib/controllers/auth_controller.dart: Active auth state controller.
- lib/controllers/exam_session_controller.dart: Active mock session state and timer logic.
- lib/controllers/institute_controller.dart: Active institute dashboard controller.
- lib/controllers/providers.dart: Dependency injection and provider definitions.
- lib/controllers/student_archive_controller.dart: Active student history controller.
- lib/controllers/student_dashboard_controller.dart: Active student dashboard controller.

#### Services
- lib/services/admin_service.dart: Active admin APIs (/admin, /analytics/admin/overview).
- lib/services/api_client.dart: Active shared HTTP client.
- lib/services/auth_service.dart: Active auth APIs.
- lib/services/exam_service.dart: Legacy-style exam service (/exams).
- lib/services/institute_service.dart: Active institute APIs.
- lib/services/mock_service.dart: Active mock session APIs.
- lib/services/student_service.dart: Active student APIs.
- lib/services/test_service.dart: Legacy-style test service (/tests).

#### Utils
- lib/utils/api_config.dart: API URL configuration.
- lib/utils/app_exceptions.dart: Error abstraction.
- lib/utils/score_utils.dart: Utility averaging logic (not core backend scoring).

#### Views/screens
- lib/views/screens/admin_exam_list_screen.dart: Active admin screen; has hardcoded reading in create-question payload.
- lib/views/screens/exam_session_screen.dart: Active student exam-taking screen.
- lib/views/screens/institute_dashboard_screen.dart: Active institute management screen.
- lib/views/screens/login_screen.dart: Active login screen.
- lib/views/screens/register_screen.dart: Active register screen.
- lib/views/screens/result_summary_screen.dart: Active result summary screen.
- lib/views/screens/splash_screen.dart: Active startup auth route chooser.
- lib/views/screens/student_archive_screen.dart: Active history screen.
- lib/views/screens/student_dashboard_screen.dart: Active dashboard screen.

#### Views/widgets
- lib/views/widgets/async_view.dart: Loading/error wrapper widget.
- lib/views/widgets/band_trend_chart.dart: Trend visualization widget.
- lib/views/widgets/section_score_card.dart: Section score card widget.

### Backend API files (lib/website_version/server/api/**/*.js)

#### Core app/config/constants
- lib/website_version/server/api/app.js: Express app setup.
- lib/website_version/server/api/config/database.js: DB connection.
- lib/website_version/server/api/config/env.js: Environment schema.
- lib/website_version/server/api/constants/roles.js: Role constants.
- lib/website_version/server/api/constants/sections.js: IELTS section constants/order/durations.

#### Middlewares
- lib/website_version/server/api/middlewares/auth.js: JWT auth and role guard.
- lib/website_version/server/api/middlewares/error-handler.js: Standard error response.
- lib/website_version/server/api/middlewares/not-found.js: 404 handler.
- lib/website_version/server/api/middlewares/validate-request.js: validator result handling.

#### Validators
- lib/website_version/server/api/validators/auth-validator.js: auth payload validation.
- lib/website_version/server/api/validators/common-validator.js: common validators including section enum.

#### Utils
- lib/website_version/server/api/utils/api-response.js: success/fail response envelope.
- lib/website_version/server/api/utils/http-error.js: HttpError abstraction.
- lib/website_version/server/api/utils/mock-generator.js: dynamic question selection.
- lib/website_version/server/api/utils/score-utils.js: objective section raw-to-band conversion.

#### V1 routes (active)
- lib/website_version/server/api/routes/v1/index.js: V1 router composition.
- lib/website_version/server/api/routes/v1/auth-routes.js: auth endpoints.
- lib/website_version/server/api/routes/v1/student-routes.js: student profile/history/analytics/purchase.
- lib/website_version/server/api/routes/v1/institute-routes.js: institute profile/student verify/codes.
- lib/website_version/server/api/routes/v1/admin-routes.js: exams/questions/templates CRUD.
- lib/website_version/server/api/routes/v1/mock-routes.js: mock session generate/answer/mark/submit/final-submit.
- lib/website_version/server/api/routes/v1/analytics-routes.js: admin overview analytics.

#### V1 services (active)
- lib/website_version/server/api/services/v1/auth-service.js: register/login/refresh/logout.
- lib/website_version/server/api/services/v1/student-service.js: student profile/history/analytics/purchase.
- lib/website_version/server/api/services/v1/institute-service.js: institute operations.
- lib/website_version/server/api/services/v1/admin-service.js: admin data management.
- lib/website_version/server/api/services/v1/mock-service.js: full mock lifecycle.
- lib/website_version/server/api/services/v1/analytics-service.js: admin analytics aggregation.

#### V1 models (active)
- lib/website_version/server/api/models/v1/User.js
- lib/website_version/server/api/models/v1/StudentProfile.js
- lib/website_version/server/api/models/v1/Question.js
- lib/website_version/server/api/models/v1/MockSession.js
- lib/website_version/server/api/models/v1/MockTemplate.js
- lib/website_version/server/api/models/v1/Exam.js
- lib/website_version/server/api/models/v1/TestHistory.js
- lib/website_version/server/api/models/v1/Institute.js
- lib/website_version/server/api/models/v1/RefreshToken.js
- lib/website_version/server/api/models/v1/DiscountCode.js

#### Legacy routes/services/models (currently not mounted in active app)
- Routes:
  - lib/website_version/server/api/routes/exam-router.js
  - lib/website_version/server/api/routes/score-router.js
  - lib/website_version/server/api/routes/student-router.js
  - lib/website_version/server/api/routes/test-router.js
- Services:
  - lib/website_version/server/api/services/exam-service.js
  - lib/website_version/server/api/services/questions-service.js
  - lib/website_version/server/api/services/score-service.js
  - lib/website_version/server/api/services/student-service.js
  - lib/website_version/server/api/services/test-service.js
- Controllers:
  - lib/website_version/server/api/controllers/exam-controller.js
  - lib/website_version/server/api/controllers/questions-controller.js
  - lib/website_version/server/api/controllers/score-controller.js
  - lib/website_version/server/api/controllers/student-controller.js
  - lib/website_version/server/api/controllers/test-controller.js
- Models:
  - lib/website_version/server/api/models/Exam.js
  - lib/website_version/server/api/models/Question.js
  - lib/website_version/server/api/models/Student.js
  - lib/website_version/server/api/models/Test.js
  - lib/website_version/server/api/models/TestHistory.js
  - lib/website_version/server/api/models/score.js
  - lib/website_version/server/api/models/index.js

## 8) Test Inventory and Gap Report

### Frontend tests
- test/widget_test.dart
  - Only a basic splash-screen smoke test.
  - Missing controller and service behavior tests.

### Backend tests
- lib/website_version/server/tests/api.test.js
  - Basic health and auth validation checks.
  - Missing mock session and scoring behavior tests.

## 9) Immediate Fix Recommendations

1. Unify section type in frontend legacy files:
- Replace int section with String section in:
  - lib/models/test_model.dart
  - lib/models/test_history.dart
  - lib/controllers/admin_test_controller.dart
  - lib/services/test_service.dart
  - dependent code paths

2. Remove hardcoded reading in admin UI:
- Update lib/views/screens/admin_exam_list_screen.dart to allow section selection.

3. Implement writing/speaking scoring strategy:
- Add rubric or evaluator workflow in backend mock-service path.

4. Clarify or remove legacy code path:
- If V1 is final, archive/remove legacy routes/services/models and legacy Flutter services/controllers.

5. Add test coverage for core flow:
- Backend: mock generation, section submit, scoring, final submit.
- Frontend: exam_session_controller timer and transitions.

---

This file is generated as a practical implementation documentation + lag report based on actual repository code.