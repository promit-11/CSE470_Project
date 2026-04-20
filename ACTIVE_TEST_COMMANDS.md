# Active Verification Commands

This document provides all commands needed to verify the active implementation of the CSE470 app.

## Frontend Tests

**Run all active frontend tests:**
```bash
flutter test test/active_*.dart --no-pub
```

**Run specific frontend test file:**
```bash
flutter test test/active_frontend_test.dart --no-pub  # 24 basic state/service tests
flutter test test/active_workflow_test.dart --no-pub  # 29 workflow behavior tests
```

**Expected output:** `00:00 +53: All tests passed!`

## Backend Tests

**Prerequisites:**
- Node.js installed
- MongoDB running (local or test instance via MONGODB_TEST_URL)

**Run all backend tests:**
```bash
cd lib/website_version/server
npm test
```

**Run specific backend test suite:**
```bash
npm test -- auth.test.js                    # Authentication & user registration
npm test -- architecture-workflows.test.js  # Multi-role workflows
npm test -- active-workflows.test.js        # NEW: Media handling, submissions, reviews
npm test -- mock-session.test.js            # Session generation & submission
npm test -- submission-scoring.test.js      # Result scoring and bands
npm test -- analytics.test.js               # Analytics tracking
npm test -- api.test.js                     # General API functionality
npm test -- discount.test.js                # Reward credits
```

## Code Quality Checks

**Flutter analysis:**
```bash
flutter analyze --no-pub lib/
```

**Dart format check:**
```bash
dart format lib/controllers/ lib/models/ lib/services/ --line-length 120 --set-exit-if-changed
```

## Full Integration Verification

**Run all checks (recommended for CI/CD):**
```bash
# 1. Frontend tests
flutter test test/active_*.dart --no-pub

# 2. Backend tests  
cd lib/website_version/server && npm test && cd ../../..

# 3. Code quality
flutter analyze --no-pub lib/

# 4. Format verification
dart format lib/controllers/ lib/models/ lib/services/ --line-length 120 --set-exit-if-changed
```

## Test Coverage Summary

| Category | Tests | File | Status |
|----------|-------|------|--------|
| **Frontend - State Management** | 8 | active_frontend_test.dart | ✅ Passing |
| **Frontend - Mock Models** | 4 | active_frontend_test.dart | ✅ Passing |
| **Frontend - Mock Service** | 8 | active_frontend_test.dart | ✅ Passing |
| **Frontend - Infrastructure** | 4 | active_frontend_test.dart | ✅ Passing |
| **Workflow - Role Access** | 3 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Session Results** | 2 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Sections** | 3 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Speaking States** | 6 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Writing Submissions** | 3 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Answers** | 2 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Timers** | 3 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Session State** | 3 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Complete Flow** | 1 | active_workflow_test.dart | ✅ Passing |
| **Workflow - Service Integration** | 3 | active_workflow_test.dart | ✅ Passing |
| **Backend - Writing Submissions** | 3 | active-workflows.test.js | ⏳ Ready |
| **Backend - Speaking Uploads** | 2 | active-workflows.test.js | ⏳ Ready |
| **Backend - Admin Question Audio** | 2 | active-workflows.test.js | ⏳ Ready |
| **Backend - Final Submit** | 1 | active-workflows.test.js | ⏳ Ready |
| **Backend - Teacher Review** | 2 | active-workflows.test.js | ⏳ Ready |
| **Backend - Reward Credits** | 2 | active-workflows.test.js | ⏳ Ready |
| **Backend - Analytics** | 2 | active-workflows.test.js | ⏳ Ready |
| **Backend - Conflict Handling** | 2 | active-workflows.test.js | ⏳ Ready |

## Troubleshooting

### Flutter Tests Won't Run
```bash
# Clear caches
flutter clean
flutter pub get

# Retry
flutter test test/active_*.dart --no-pub
```

### Backend Tests Fail
```bash
# Check MongoDB is running
# Set connection string if needed:
export MONGODB_TEST_URL=mongodb://localhost:27017/cse470_test

# Try again
npm test
```

### Analysis Errors
```bash
# Regenerate platform bindings
flutter pub get
flutter pub upgrade

# Re-analyze
flutter analyze --no-pub lib/
```

## Notes

- Frontend tests avoid Flutter platform channels by testing state models directly
- Backend tests use Supertest for HTTP requests and MongoDB for persistence
- All tests use test factories and mocks to avoid external dependencies
- Tests focus on active runtime behavior only (no legacy/unmounted features)
