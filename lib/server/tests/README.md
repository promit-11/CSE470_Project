# Backend Test Suite Documentation

## Overview

The backend test suite provides comprehensive coverage of critical API functionality using Node.js's built-in `test` module with `supertest` for HTTP testing.

### Test Files

| File | Coverage | Tests |
|------|----------|-------|
| `api.test.js` | Health check endpoints | 1 |
| `auth.test.js` | Authentication (register, login, refresh, logout) | 10 |
| `mock-session.test.js` | Mock exam generation, section structure, question distribution | 13 |
| `submission-scoring.test.js` | Answer submission, flagging, section submission, scoring, final results | 15 |
| `analytics.test.js` | History persistence, analytics computation, trend tracking | 11 |
| `discount.test.js` | Institute discount logic, application rules, eligibility | 12 |
| **Total** | | **62 tests** |

## Running Tests

### Prerequisites

1. **Node.js**: v18+ (built-in test module support)
2. **MongoDB**: Running instance (local or test database)
3. **Environment Variables**: Set `MONGODB_TEST_URL` for test database (defaults to `mongodb://localhost:27017/cse470_test`)

### Commands

```bash
# Run all tests
npm test

# Run specific test file
npm test tests/auth.test.js

# Run tests with verbose output
node --test tests/*.test.js --reporter=verbose

# Run tests matching pattern
npm test -- --grep "should"
```

### Test Database

Tests use a separate test database to avoid affecting production data:

```bash
# Set test database URL (default shown)
export MONGODB_TEST_URL=mongodb://localhost:27017/cse470_test
npm test
```

**Important**: Each test suite automatically:
- Connects to the test database before running
- Cleans up all test collections after each test
- Disconnects after completing all tests

## Test Structure

### Shared Fixtures (`fixtures.js`)

Provides reusable test data and utility functions:

```javascript
// Create test user
const user = await createTestUser({ 
  email: "test@example.com",
  role: "student"
});

// Create student profile with mock access
const profile = await createTestStudentProfile(user);

// Create question bank (40 listening, 40 reading, 2 writing, 3 speaking)
await createFullQuestionBank();

// Create mock template with custom configuration
const template = await createTestTemplate({
  sectionQuestionCount: { listening: 35, ... }
});

// Create institute and admin user
const institute = await createTestInstitute(adminUser);

// Create discount code
const discount = await createTestDiscountCode(institute, {
  discountType: "percentage",
  discountValue: 10
});

// Clean all test data
await cleanupDatabase();
```

### Test Organization

Each test file uses Node's test runner:

```javascript
test("Feature Suite", async (t) => {
  // Setup: runs once before all tests
  await t.before(async () => {
    // Connect to database
  });

  // Cleanup: runs after each individual test
  await t.beforeEach(async () => {
    await cleanupDatabase();
  });

  // Individual test
  await t.test("Should do something", async () => {
    // Arrange
    const user = await createTestUser();
    
    // Act
    const result = await someFunction(user);
    
    // Assert
    assert.equal(result.status, "success");
  });

  // Teardown: runs once after all tests
  await t.after(async () => {
    await mongoose.disconnect();
  });
});
```

## Test Coverage Summary

### 1. Authentication (auth.test.js) - 10 tests

**Covered**:
- ✅ Register validation (name, email, password, role)
- ✅ Register success with account/profile creation
- ✅ Duplicate email rejection
- ✅ Login validation (invalid email, wrong password)
- ✅ Login success with token generation
- ✅ Inactive account rejection
- ✅ Refresh token validation
- ✅ Logout token revocation

**Example**:
```javascript
await t.test("Login - should successfully login with correct credentials", async () => {
  const user = await createTestUser({ email: "user@example.com" });
  
  const response = await request(app)
    .post("/api/v1/auth/login")
    .send({
      email: "user@example.com",
      password: FIXTURE_DATA.PASSWORD,
    });

  assert.equal(response.statusCode, 200);
  assert.ok(response.body.data.accessToken);
});
```

### 2. Mock Session Generation (mock-session.test.js) - 13 tests

**Covered**:
- ✅ Session generation with/without mock access
- ✅ Credit consumption
- ✅ Section structure (order, counts, durations)
- ✅ Question distribution per section
- ✅ Repetition prevention (maxRepeatRate threshold)
- ✅ Template adherence
- ✅ Database persistence

**Example**:
```javascript
await t.test("Should distribute correct question counts per section", async () => {
  const session = await generateMockSession(String(testUser._id));

  const expectedCounts = {
    listening: 40,
    reading: 40,
    writing: 2,
    speaking: 3,
  };

  for (const section of session.sections) {
    assert.equal(
      section.questionIds.length,
      expectedCounts[section.section]
    );
  }
});
```

### 3. Submission & Scoring (submission-scoring.test.js) - 15 tests

**Covered**:
- ✅ Answer submission for current section
- ✅ Question flagging/unflagging
- ✅ Section submission and progression
- ✅ Listening score calculation (raw → band)
- ✅ Reading score calculation (raw → band)
- ✅ Writing section submission (essay responses)
- ✅ Speaking section submission (spoken responses)
- ✅ Final submission and TestHistory creation
- ✅ Overall band aggregation

**Example**:
```javascript
await t.test("Should calculate correct listening score", async () => {
  // Get questions and their correct answers
  const allQuestions = await Question.find({ section: "listening" });
  
  // Submit correct answers for 30+ questions
  for (let i = 0; i < 30; i++) {
    await saveAnswer(userId, sessionId, "listening", questionId, correctAnswer);
  }
  
  // Submit section
  await submitSection(userId, sessionId, "listening");
  
  // Verify band score (30+ correct = 7.0+)
  const updated = await MockSession.findById(sessionId);
  assert.ok(updated.sections[0].bandScore >= 6.5);
});
```

### 4. Analytics & History (analytics.test.js) - 11 tests

**Covered**:
- ✅ History retrieval and ordering
- ✅ Analytics computation (section averages, overall band)
- ✅ Trend tracking across multiple tests
- ✅ Latest test inclusion
- ✅ Feedback persistence
- ✅ Incomplete session exclusion

**Example**:
```javascript
await t.test("Should compute section averages from multiple tests", async () => {
  // Complete 3 sessions
  for (let i = 0; i < 3; i++) {
    const session = await generateMockSession(userId);
    // ... submit all sections ...
    await finalSubmit(userId, session._id);
  }
  
  const analytics = await getMyAnalytics(userId);
  
  assert.equal(analytics.totalMocks, 3);
  assert.ok(typeof analytics.sectionAverages.listening === "number");
});
```

### 5. Discount Application (discount.test.js) - 12 tests

**Covered**:
- ✅ Discount eligibility (verification, limits, dates)
- ✅ Fixed discount application
- ✅ Percentage discount application
- ✅ Usage limit enforcement
- ✅ Validity date validation
- ✅ Student eligibility lists
- ✅ Best discount selection
- ✅ Credit top-up on purchase

**Example**:
```javascript
await t.test("Should apply fixed discount to eligible verified student", async () => {
  testProfile.verifiedByInstitute = true;
  testProfile.instituteId = testInstitute._id;
  await testProfile.save();

  testDiscount.discountType = "fixed";
  testDiscount.discountValue = 50;
  await testDiscount.save();

  const result = await purchaseMockAccess(userId, 5);

  assert.equal(result.discountAmount, 50);
  assert.ok(result.finalAmount < result.subtotal);
});
```

## Test Design Principles

### 1. **Deterministic**
- Uses fixed test data, not random values
- Seeds question bank before each test
- No time-dependent assertions (except date comparisons)

### 2. **Isolated**
- Each test cleans database before running
- No test interdependencies
- Tests can run in any order

### 3. **Focused**
- Tests one behavior per test function
- Clear arrange-act-assert structure
- Meaningful assertion messages

### 4. **Comprehensive**
- Happy path and error cases
- Edge cases (empty data, limits, boundaries)
- Integration (database persistence, calculations)

## Adding New Tests

### Step 1: Create Test File

```javascript
// tests/new-feature.test.js
import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import { createTestUser, cleanupDatabase } from "./fixtures.js";

test("New Feature Suite", async (t) => {
  await t.before(async () => {
    const mongoUrl = process.env.MONGODB_TEST_URL || "mongodb://localhost:27017/cse470_test";
    if (mongoose.connection.readyState !== 1) {
      await mongoose.connect(mongoUrl, {
        connectTimeoutMS: 5000,
        serverSelectionTimeoutMS: 5000,
      });
    }
  });

  await t.beforeEach(async () => {
    await cleanupDatabase();
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("Should do something", async () => {
    // Test code here
  });
});
```

### Step 2: Add Fixtures (if needed)

Edit `fixtures.js`:

```javascript
export async function createMyCustomFixture(override = {}) {
  const defaults = { /* ... */ };
  return SomeModel.create({ ...defaults, ...override });
}
```

### Step 3: Run Tests

```bash
npm test tests/new-feature.test.js
```

## Troubleshooting

### MongoDB Connection Errors

```bash
# Ensure MongoDB is running
mongosh

# Or set custom test DB URL
export MONGODB_TEST_URL=mongodb://localhost:27017/cse470_test
npm test
```

### Timeouts

Increase timeout for slow tests:

```javascript
await t.test("Slow test", { timeout: 10000 }, async () => {
  // Test code
});
```

### Assertion Failures

Use descriptive messages:

```javascript
assert.equal(
  actual,
  expected,
  `Expected ${expected} but got ${actual} for section ${section}`
);
```

## Test Statistics

```
Total Tests:  62
Total Suites: 6

Coverage Areas:
- Authentication: 10 tests (16%)
- Session Generation: 13 tests (21%)
- Submission/Scoring: 15 tests (24%)
- Analytics: 11 tests (18%)
- Discounts: 12 tests (19%)
- Health: 1 test (2%)

Runtime: ~10-15 seconds (depends on system)
Database: Test-only, auto-cleaned between tests
```

## Future Enhancements

- [ ] Add rate limiting tests
- [ ] Add concurrent session tests
- [ ] Add token expiration tests
- [ ] Add error recovery tests
- [ ] Add performance benchmarks
- [ ] Add accessibility/audit tests
- [ ] Increase reading/writing/speaking section coverage

## References

- [Node.js Test Module](https://nodejs.org/api/test.html)
- [Supertest](https://github.com/visionmedia/supertest)
- [Mongoose Testing Guide](https://mongoosejs.com/docs/testing.html)
