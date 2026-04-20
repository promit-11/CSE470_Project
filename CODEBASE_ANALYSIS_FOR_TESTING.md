# CSE470 App - Codebase Analysis for Workflow Testing

## 1. ROUTES & NAVIGATION

### Route Definitions
**File:** [lib/routes/app_routes.dart](lib/routes/app_routes.dart)
```
- splash = '/'
- login = '/login'
- register = '/register'
- roleHome = '/home'
- studentDashboard = '/student/dashboard'
- studentProfile = '/student/profile'
- studentAnalytics = '/student/analytics'
- studentArchive = '/student/archive'
- studentCoachingAssignment = '/student/coaching-assignment'
- studentExam = '/student/exam'
- studentResult = '/student/result'
- teacherPendingApproval = '/teacher/pending-approval'
- teacherDashboard = '/teacher/dashboard'
- teacherReviewDetail = '/teacher/review-detail'
- coachingDashboard = '/coaching/dashboard'
- adminExams = '/admin/exams'
```

### Router Implementation
**File:** [lib/routes/app_router.dart](lib/routes/app_router.dart)
- `AppRouter.onGenerateRoute()` - Routes all navigation with role-based screen handling
- Passes arguments: `TeacherPendingApprovalScreen(email)`, `TeacherReviewDetailScreen(evaluationRequestId)`

---

## 2. KEY WIDGETS & CONTROLLERS

### Screen Widgets
**Location:** `lib/views/screens/`

**Student Screens:**
- [student_dashboard_screen.dart](lib/views/screens/student_dashboard_screen.dart) - `StudentDashboardScreen` 
  - Shows analytics, session history, coaching status card
  - Uses `studentDashboardControllerProvider`
  
- [student_coaching_assignment_screen.dart](lib/views/screens/student_coaching_assignment_screen.dart) - `StudentCoachingAssignmentScreen`
  - Form to request coaching assignment with admissionCode and coachingId
  - Shows active assignment status and pending request status
  
- [student_archive_screen.dart](lib/views/screens/student_archive_screen.dart) - `StudentArchiveScreen`
  - Shows historical test sessions and results

- [exam_session_screen.dart](lib/views/screens/exam_session_screen.dart) - `ExamSessionScreen`
  - Mock test/exam UI with timer, questions, section navigation
  - Handles writing (typed + images), reading, listening, speaking (recording)
  - Resume functionality via `sessionId` argument

- [result_summary_screen.dart](lib/views/screens/result_summary_screen.dart) - `ResultSummaryScreen`
  - Shows session result: overall status (finalized/pending_full_review/partial_unavailable_sections)
  - Section-level status (completed/pending_review/reviewed/not_submitted)
  - Score breakdowns

**Teacher Screens:**
- [teacher_pending_approval_screen.dart](lib/views/screens/teacher_pending_approval_screen.dart) - `TeacherPendingApprovalScreen`
  - Shows pending approval message with email
  - Link back to login

- [teacher_dashboard_screen.dart](lib/views/screens/teacher_dashboard_screen.dart) - `TeacherDashboardScreen`
  - Lists: pending requests, claimed requests, reviewed requests, payout requests
  - Auto-refresh queue (20s interval)
  - Request payout dialog

- [teacher_review_detail_screen.dart](lib/views/screens/teacher_review_detail_screen.dart) - `TeacherReviewDetailScreen`
  - Form for submitting evaluation review: overallBand (0-9), strengths/weaknesses, criterion scores
  - Plays speaking recording
  - Shows student's submission (writing typed, images, listening answers, etc.)

**Admin Screens:**
- [admin_exam_list_screen.dart](lib/views/screens/admin_exam_list_screen.dart) - `AdminExamListScreen`
  - Create/manage exams, questions, templates
  - Approve teachers, manage payouts
  - List students, teachers, coachings

**Coaching Admin Screen:**
- [institute_dashboard_screen.dart](lib/views/screens/institute_dashboard_screen.dart) - `InstituteDashboardScreen`
  - Manage students, discount codes, assignment requests
  - Manage teachers, exams, templates
  - Auto-refresh (20s interval)

**Auth Screens:**
- [login_screen.dart](lib/views/screens/login_screen.dart) - `LoginScreen`
- [register_screen.dart](lib/views/screens/register_screen.dart) - `RegisterScreen`
- [splash_screen.dart](lib/views/screens/splash_screen.dart) - `SplashScreen`

### Controllers
**Location:** `lib/controllers/`

- [auth_controller.dart](lib/controllers/auth_controller.dart) - `AuthController`
  - State: `isLoading`, `isInitialized`, `errorMessage`, `currentUser`, `accessToken`, `refreshToken`, `isAuthenticated`
  - Methods: `initialize()`, `register()`, `login()`, `logout()`, `refresh()`, `clearAuth()`

- [student_dashboard_controller.dart](lib/controllers/student_dashboard_controller.dart) - `StudentDashboardController`
  - State: `isLoading`, `analytics` (StudentAnalytics), `profile`, `isPurchasing`, `coachingFormData`
  - Methods: `load()`, `purchaseMockAccess(packSize)`

- [student_coaching_assignment_controller.dart](lib/controllers/student_coaching_assignment_controller.dart) - `StudentCoachingAssignmentController`
  - State: `isLoading`, `isSubmitting`, `formData` (CoachingAssignmentFormData), `lastSuccessMessage`
  - Methods: `load()`, `submitRequest(coachingId, admissionCode)`

- [exam_session_controller.dart](lib/controllers/exam_session_controller.dart) - `ExamSessionController`
  - State: `isLoading`, `session` (MockSession), `remainingSeconds`, `currentQuestionIndex`, `answers`, `flagged`, `isSubmitting`
  - State: `writingMode` (typed/images), `writingTypedDraft`, `writingImages`, `speakingRecording`, `speakingRecordingState`
  - Methods: `startSession()`, `loadSession(sessionId)`, `saveAnswer(section, qId, value)`, `markQuestion(section, qId, flagged)`
  - Methods: `submitSection(section)`, `finalSubmit()`, `saveWritingTyped(text)`, `uploadWritingImages(files)`
  - Methods: `recordSpeaking()`, `stopRecording()`, `uploadSpeakingRecording()`

- [teacher_dashboard_controller.dart](lib/controllers/teacher_dashboard_controller.dart) - `TeacherDashboardController`
  - State: `profile` (TeacherProfileModel), `pendingRequests`, `claimedRequests`, `reviewedRequests`, `payoutRequests`
  - Methods: `load()`, `claimRequest(id)`, `requestPayout(credits, note)`, `startQueueRefresh()`, `stopQueueRefresh()`

- [admin_dashboard_controller.dart](lib/controllers/admin_dashboard_controller.dart) - `AdminDashboardController`
  - State: `overview`, `exams`, `questions`, `templates`, `students`, `teachers`, `coachings`
  - State: `pendingApprovalTeachers`, `pendingPayoutRequests`, counters
  - Methods: `load()`, `createExam()`, `createQuestion()`, `createTemplate()`, `approveTeacher()`, `rejectTeacher()`, `approvePayoutRequest()`, etc.

- [institute_controller.dart](lib/controllers/institute_controller.dart) - `InstituteController`
  - State: `profile`, `students`, `discountCodes`, `assignmentRequests`, `teachers`, `availableTeachers`, `exams`, `questions`, `templates`, `evaluationActivity`
  - Methods: `load()`, `acceptAssignmentRequest()`, `rejectAssignmentRequest()`, `assignTeacher()`, `removeTeacher()`, etc.

---

## 3. BACKEND API ENDPOINTS

### Base URL Structure
**Location:** `lib/website_version/server/api/routes/v1/`

All routes require auth: `requireAuth` + `allowRoles(ROLE)`

#### Auth Routes
**File:** `auth-routes.js`
```
POST   /v1/auth/register
POST   /v1/auth/login
POST   /v1/auth/refresh
POST   /v1/auth/logout
GET    /v1/auth/me
```

#### Student Routes
**File:** `student-routes.js`
- **Profile & Analytics:**
  ```
  GET    /v1/students/profile
  PUT    /v1/students/profile (targetBand, strengths, weaknesses)
  GET    /v1/students/history
  GET    /v1/students/analytics
  ```

- **Coaching Assignment:**
  ```
  GET    /v1/students/coaching-assignment/form
  POST   /v1/students/coaching-assignment/request (coachingId, admissionCode)
  ```

- **Credits & Purchase:**
  ```
  GET    /v1/students/credits/packages
  POST   /v1/students/credits/purchase (packageId)
  POST   /v1/students/purchase-mock-access (packSize)
  GET    /v1/students/payments
  ```

#### Teacher Routes
**File:** `teacher-routes.js`
```
GET    /v1/teachers/profile
GET    /v1/teachers/evaluation-requests/pending
PATCH  /v1/teachers/evaluation-requests/:id/claim
GET    /v1/teachers/evaluation-requests/claimed
GET    /v1/teachers/evaluation-requests/reviewed
GET    /v1/teachers/evaluation-requests/:id
POST   /v1/teachers/evaluation-requests/:id/review (overallBand, strengths, weaknesses, criterionScores, comments)
POST   /v1/teachers/payouts/request (requestedRewardCredits, note)
GET    /v1/teachers/payouts
```

#### Mock Session Routes
**File:** `mock-routes.js`
```
POST   /v1/mock-sessions/generate (templateId?, sourceType?)
GET    /v1/mock-sessions/:id
POST   /v1/mock-sessions/:id/answer (section, questionId, value)
POST   /v1/mock-sessions/:id/mark (section, questionId, flagged)
POST   /v1/mock-sessions/:id/submit-section (section, autoSubmitted?)
POST   /v1/mock-sessions/:id/final-submit
PATCH  /v1/mock-sessions/:id/writing/typed-response (typedAnswer)
POST   /v1/mock-sessions/:id/writing/images (multipart: writingImages)
DELETE /v1/mock-sessions/:id/writing/images/:mediaId
PATCH  /v1/mock-sessions/:id/writing/images/reorder (orderedMediaIds)
POST   /v1/mock-sessions/:id/speaking/recording (multipart: speakingRecording)
```

#### Admin Routes
**File:** `admin-routes.js`
```
GET    /v1/admin/overview
GET    /v1/admin/exams
POST   /v1/admin/exams (title, description)
PUT    /v1/admin/exams/:id
DELETE /v1/admin/exams/:id
GET    /v1/admin/questions (?section)
POST   /v1/admin/questions (multipart: section, questionType, title, content, listeningAudio)
PUT    /v1/admin/questions/:id
DELETE /v1/admin/questions/:id
GET    /v1/admin/templates
POST   /v1/admin/templates
PUT    /v1/admin/templates/:id
DELETE /v1/admin/templates/:id
GET    /v1/admin/students (?page, ?limit)
GET    /v1/admin/teachers (?state: pending_approval/approved/deactivated, ?page, ?limit)
PATCH  /v1/admin/teachers/:id/approve
PATCH  /v1/admin/teachers/:id/lifecycle (action: reject|deactivate, reason?)
GET    /v1/admin/coachings
GET    /v1/admin/evaluation-requests (?status)
GET    /v1/admin/payment-transactions
GET    /v1/admin/payouts (?status: pending/approved/rejected)
PATCH  /v1/admin/payouts/:id/approve (approvalNote)
PATCH  /v1/admin/payouts/:id/reject (rejectionReason)
```

#### Institute (Coaching Admin) Routes
**File:** `institute-routes.js`
```
GET    /v1/institutes/profile
PUT    /v1/institutes/profile (name, description, address, contactPhone)
POST   /v1/institutes/students/verify (email)
GET    /v1/institutes/students (?page, ?limit)
POST   /v1/institutes/assignment-requests/:id/accept
POST   /v1/institutes/assignment-requests/:id/reject (reason?)
GET    /v1/institutes/assignment-requests/incoming
GET    /v1/institutes/teachers (?page, ?limit)
POST   /v1/institutes/teachers/:id/assign (assignmentNote?)
PATCH  /v1/institutes/teachers/:id/remove
GET    /v1/institutes/teachers/available
GET    /v1/institutes/exams
POST   /v1/institutes/exams
PUT    /v1/institutes/exams/:id
DELETE /v1/institutes/exams/:id
GET    /v1/institutes/questions (?section)
POST   /v1/institutes/questions (multipart)
PUT    /v1/institutes/questions/:id
DELETE /v1/institutes/questions/:id
GET    /v1/institutes/templates
POST   /v1/institutes/templates
PUT    /v1/institutes/templates/:id
DELETE /v1/institutes/templates/:id
POST   /v1/institutes/discount-codes
GET    /v1/institutes/discount-codes
GET    /v1/institutes/evaluation-requests/activity
```

#### Analytics Routes
**File:** `analytics-routes.js`
```
GET    /v1/analytics/... (various analytics endpoints)
```

---

## 4. DATA MODELS

### Dart Models
**Location:** `lib/models/`

#### User & Auth Models
[auth_models.dart](lib/models/auth_models.dart):
- `AppUser` - id, name, email, role (student/teacher/coaching_admin/platform_admin), status, approvalStatus

#### Dashboard Models
[dashboard_models.dart](lib/models/dashboard_models.dart):
- `StudentAnalytics` - bands, scores, trends, certifications
- `StudentHistoryEntry` - session info, dates, results

#### Coaching Assignment Models
[coaching_assignment_models.dart](lib/models/coaching_assignment_models.dart):
- `CoachingCenterOption` - id, name, description, address, contactEmail, contactPhone
- `CoachingAssignmentPrefilled` - userId, name, email, profileId, coachingId, studentMode
- `CoachingAssignmentFormData` - prefilled data, available coachings, assignment status
- `CoachingAssignmentStatus` - hasActiveAssignment, requestStatus (pending/accepted/rejected)

#### Teacher Models
[teacher_models.dart](lib/models/teacher_models.dart):
- `TeacherProfileModel` - id, userId, coachingId, rewardCredits, bio, expertiseTags
- `TeacherMediaMetadata` - mediaId, fileName, mimeType, sizeBytes, publicUrl, uploadedAt, pageOrder
- `EvaluationRequestModel` - id, studentId, sessionId, status, submission details, teacher assignment
- `EvaluationQuestionSummary` - id, section, questionType, category, status, scoreRanges
- `TeacherReviewPayload` - overallBand, strengths, weaknesses, criterionScores, comments
- `TeacherReviewSubmitResult` - success status, updatedRequest
- `TeacherPayoutRequestModel` - id, status, credits, amount, createdAt, resolvedAt
- `TeacherDashboardSummary` - profile, pending, claimed, reviewed, payouts

#### Admin Models
[admin_models.dart](lib/models/admin_models.dart):
- `AdminOverviewData` - students count, teachers count, coachings, completedSessions, pendingRequests
- `AdminTeacherSummary` - userId, name, email, status, approvalStatus, rewardCredits, coachingAssigned
- `AdminPayoutRequestSummary` - id, status, teacherInfo, credits, amount, dates, notes/reasons

#### Coaching Models
[coaching_models.dart](lib/models/coaching_models.dart):
- `CoachingStudentSummary` - id, userId, name, email, verifiedByInstitute
- `CoachingAssignmentRequestSummary` - id, status, admissionCode, studentInfo, createdAt
- `CoachingTeacherSummary` - teacherUserId, name, email, approvalStatus, accountStatus, rewardCredits, expertiseTags
- `AvailableTeacherSummary` - basic teacher info for assignment selection
- `CoachingExamSummary` - exam details within coaching context
- `CoachingProfile` - institute details

#### Mock Test Models
[mock_models.dart](lib/models/mock_models.dart):
- `MockSession` - id, studentId, status (ongoing/completed), currentSection, time limits
- `MockSection` - section name, duration, questions, answers, submission status
- `MockSectionState` - questions, isSubmitted, answers
- `MockQuestion` - id, section, questionType, title, content, options, listeningAudioUrl
- `MockQuestionOption` - key, text
- `MockMediaMetadata` - mediaId, fileName, mimeType, sizeBytes, publicUrl, pageOrder
- `MockWritingSubmission` - mode (typed/images/none), typedAnswer, images list
- `MockSpeakingSubmission` - mediaMetadata details
- `MockResult` - overall status, section results, scores

---

## 5. SERVICE METHODS

### Dart Services
**Location:** `lib/services/`

#### AuthService
[auth_service.dart](lib/services/auth_service.dart):
```dart
- Future<Map> register(Map payload)
- Future<Map> login(String email, String password)
- Future<AppUser> me()
- Future<Map> refresh(String refreshToken)
- Future<void> logout(String refreshToken)
```

#### StudentService
[student_service.dart](lib/services/student_service.dart):
```dart
- Future<Map> getProfile()
- Future<Map> updateProfile(Map payload)
- Future<List<StudentHistoryEntry>> getHistory()
- Future<StudentAnalytics> getAnalytics()
- Future<Map> purchaseMockAccess({packSize})
- Future<CoachingAssignmentFormData> getCoachingAssignmentForm()
- Future<Map> submitCoachingAssignmentRequest({coachingId, admissionCode})
- Future<Map> getCreditPackages()
- Future<Map> purchaseTestCredits({packageId})
- Future<List> getPayments()
```

#### TeacherService
[teacher_service.dart](lib/services/teacher_service.dart):
```dart
- Future<TeacherProfileModel> getProfile()
- Future<List<EvaluationRequestModel>> getPendingRequests()
- Future<List<EvaluationRequestModel>> getClaimedRequests()
- Future<List<EvaluationRequestModel>> getReviewedRequests()
- Future<EvaluationRequestModel> claimRequest(String id)
- Future<EvaluationRequestModel> getRequestDetail(String id)
- Future<TeacherReviewSubmitResult> submitReview(String id, TeacherReviewPayload payload)
- Future<Map> requestPayout({requestedRewardCredits, note})
- Future<List<TeacherPayoutRequestModel>> getPayoutRequests()
- Future<TeacherDashboardSummary> getDashboardSummary()
```

#### MockService
[mock_service.dart](lib/services/mock_service.dart):
```dart
- Future<MockSession> generateSession()
- Future<MockSession> getSession(String sessionId)
- Future<void> saveAnswer({sessionId, section, questionId, value})
- Future<void> markQuestion({sessionId, section, questionId, flagged})
- Future<MockSession> submitSection({sessionId, section, autoSubmitted})
- Future<MockSession> finalSubmit(String sessionId)
- Future<MockSession> saveWritingTypedResponse({sessionId, typedAnswer})
- Future<MockSession> uploadWritingImages({sessionId, files})
- Future<MockSession> deleteWritingImage({sessionId, mediaId})
- Future<MockSession> reorderWritingImages({sessionId, orderedMediaIds})
- Future<MockSession> uploadSpeakingRecording({sessionId, filePath, fileName, mimeType})
```

#### AdminService
[admin_service.dart](lib/services/admin_service.dart):
```dart
- Future<List> getExams()
- Future<void> createExam(Map payload)
- Future<void> deleteExam(String examId)
- Future<List> getQuestions({section})
- Future<Map> createQuestion(Map payload, {listeningAudioFile})
- Future<Map> updateQuestion(String id, Map payload, {listeningAudioFile})
- Future<void> deleteQuestion(String id)
- Future<List> getTemplates()
- Future<void> createTemplate(Map payload)
- Future<List> getStudents({page, limit})
- Future<List> getTeachers({state, page, limit})
- Future<Map> approveTeacher(String id)
- Future<Map> rejectTeacher(String id, String reason)
- Future<Map> approvePayoutRequest(String id, String note)
- Future<Map> rejectPayoutRequest(String id, String reason)
```

#### InstituteService
[institute_service.dart](lib/services/institute_service.dart):
```dart
- Future<Map> getProfile()
- Future<Map> updateInstitute(Map payload)
- Future<Map> verifyStudent(String email)
- Future<List<CoachingStudentSummary>> listStudents({page, limit})
- Future<List<Map>> listDiscountCodes()
- Future<List<CoachingAssignmentRequestSummary>> listAssignmentRequests()
- Future<bool> acceptAssignmentRequest(String id)
- Future<bool> rejectAssignmentRequest(String id, {reason})
- Future<List<CoachingTeacherSummary>> listTeachers({page, limit})
- Future<List<AvailableTeacherSummary>> listAvailableTeachers()
- Future<bool> assignTeacher(String teacherId, {assignmentNote})
- Future<bool> removeTeacher(String teacherId)
- Future<List<Map>> getExams()
- Future<List<Map>> getQuestions({section})
- Future<List<Map>> getTemplates()
- Future<Map> getEvaluationActivity({status})
```

#### ApiClient
[api_client.dart](lib/services/api_client.dart):
```dart
- Future<dynamic> get(String path)
- Future<dynamic> post(String path, Map payload)
- Future<dynamic> put(String path, Map payload)
- Future<dynamic> patch(String path, Map payload)
- Future<dynamic> delete(String path)
- Future<dynamic> postMultipart(String path, FormData)
- void setAccessToken(String token)
```

### Backend Services
**Location:** `lib/website_version/server/api/services/v1/`

- [auth-service.js](lib/website_version/server/api/services/v1/auth-service.js) - registerUser, loginUser, refreshAccessToken, logout
- [student-service.js](lib/website_version/server/api/services/v1/student-service.js) - profile, history, analytics, coaching, credits
- [teacher-service.js](lib/website_version/server/api/services/v1/teacher-service.js) - profile, requests (pending/claimed/reviewed), review submission, payouts
- [mock-service.js](lib/website_version/server/api/services/v1/mock-service.js) - session generation, answer/marking, submissions, media upload
- [admin-service.js](lib/website_version/server/api/services/v1/admin-service.js) - CRUD exams/questions/templates, teacher approval, payout approval
- [institute-service.js](lib/website_version/server/api/services/v1/institute-service.js) - coaching profile, students, teachers, exams, assignment requests
- [finance-service.js](lib/website_version/server/api/services/v1/finance-service.js) - payment transactions, payout handling
- [media-storage-service.js](lib/website_version/server/api/services/v1/media-storage-service.js) - upload/download media files

---

## 6. KEY WORKFLOWS TO TEST

### 1. **Student Mock Test Workflow**
- Generate session → Answer questions (all sections) → Submit section → Final submit → View results
- Writing: Save typed response + upload images + reorder
- Speaking: Record audio → Upload
- Resume session handling

### 2. **Teacher Evaluation Workflow**
- View pending requests (queue) → Claim request → Load detail → Review submission → Submit scores/feedback → View payout requests

### 3. **Coaching Assignment Workflow**
- Student views coaching form → Selects coaching center → Enters admission code → Submits request → Status tracking
- Coaching admin: Views pending requests → Accept/Reject requests

### 4. **Teacher Approval Workflow** (Platform Admin)
- Register teacher → Pending approval screen → Admin approves/rejects → Teacher can access features

### 5. **Payout Workflow**
- Teacher requests payout → Admin views payout requests → Approve/reject → Payment processed

### 6. **Admin Content Management**
- Create exams → Create questions (with audio) → Create templates → Manage content

### 7. **Coaching Admin Dashboard**
- Manage students (verify), teachers (assign/remove), discount codes, exams/templates, evaluate assignments

---

## 7. UI COMPONENTS & WIDGETS

**Location:** `lib/views/widgets/`

- [async_view.dart](lib/views/widgets/async_view.dart) - `AsyncView` - Loading/error/data states
- [band_trend_chart.dart](lib/views/widgets/band_trend_chart.dart) - `BandTrendChart` - Analytics visualization
- [section_score_card.dart](lib/views/widgets/section_score_card.dart) - `SectionScoreCard` - Result display
- [ui_components.dart](lib/views/widgets/ui_components.dart) - `SectionCard`, `PrimaryButton`, `SecondaryButton`, `LoadingIndicator`, etc.

---

## TEST COVERAGE PRIORITIES

### High Priority (Core Workflows)
1. ✅ Auth: Login/Register/Logout
2. ✅ Student: Mock test generation, answer questions, submit session, view results
3. ✅ Teacher: Claim request, submit review, request payout
4. ✅ Coaching Assignment: Submit request, track status
5. ✅ Admin: Approve teachers, approve payouts

### Medium Priority (Role-Specific Features)
1. Coaching Admin: Manage students, assign teachers, manage discount codes
2. Admin: Create exams/questions/templates
3. Student: Purchase mock access, view analytics
4. Teacher: Queue refresh, profile management

### Lower Priority (Edge Cases)
1. Session resume
2. Media reordering
3. Error handling and recovery
4. Permission/authorization checks

