# IELTS Mock Test & Coaching Collaboration Platform

Production-oriented upgrade of the existing IELTS practice app into a secure, role-based platform with:

- Student mock test lifecycle (Listening -> Reading -> Writing -> Speaking)
- Section timer and auto-submit support
- Objective scoring and IELTS band mapping
- Test history and trend analytics
- Coaching institute management with student verification and discount codes
- Platform admin question-bank and mock configuration controls

## 1) Architecture Overview

### Frontend

- Flutter + Riverpod (StateNotifier)
- Dio API client
- Secure token persistence via flutter_secure_storage
- Role-aware route flows

### Backend

- Node.js + Express
- MongoDB + Mongoose
- JWT access + refresh token strategy
- bcrypt password hashing
- Validation via express-validator
- Centralized error handling and response envelope

## 2) Folder Structure

### Flutter

- lib/models: typed auth/mock/analytics models
- lib/services: API integration services per domain
- lib/controllers: Riverpod state notifiers
- lib/views/screens: role-specific and exam session screens
- lib/views/widgets: reusable widgets including trend chart
- lib/routes: centralized route constants + router

### Backend

- lib/website_version/server/api/config: env + database
- lib/website_version/server/api/constants: roles/sections
- lib/website_version/server/api/models/v1: secure domain schemas
- lib/website_version/server/api/services/v1: business logic layer
- lib/website_version/server/api/routes/v1: API endpoints
- lib/website_version/server/api/middlewares: auth/validation/error
- lib/website_version/server/scripts: seed script
- lib/website_version/server/tests: API smoke tests

## 3) Database Schema Design

Implemented v1 collections:

- V1User: name, email, passwordHash, role, status
- V1StudentProfile: userId, instituteId, verifiedByInstitute, strengths, weaknesses
- V1Institute: profile and admin linkage
- V1DiscountCode: institute discount policy and validity
- V1Question: section/category/difficulty/questionType/options/answerKey
- V1Exam: exam metadata
- V1MockTemplate: section order and distribution config
- V1MockSession: generated questions, answers, flagged state, section scores, overall band
- V1RefreshToken: refresh token revocation and expiry
- V1TestHistory: persisted completed mock outcomes

## 4) API Contracts (Core)

Base prefix: /api/v1

### Auth

- POST /auth/register
- POST /auth/login
- POST /auth/refresh
- POST /auth/logout
- GET /auth/me

### Student

- GET /students/profile
- PUT /students/profile
- GET /students/history
- GET /students/analytics

### Institute (coaching_admin)

- GET /institutes/profile
- PUT /institutes/profile
- POST /institutes/students/verify
- GET /institutes/students
- GET /institutes/discount-codes
- POST /institutes/discount-codes

### Platform Admin

- GET/POST/PUT/DELETE /admin/exams
- GET/POST/PUT/DELETE /admin/questions
- GET/POST/PUT /admin/mock-templates

### Mock Engine

- POST /mock-sessions/generate
- GET /mock-sessions/:id
- POST /mock-sessions/:id/answer
- POST /mock-sessions/:id/mark
- POST /mock-sessions/:id/submit-section
- POST /mock-sessions/:id/final-submit

### Analytics

- GET /analytics/admin/overview

## 5) Security Design

- Password hashing: bcryptjs
- Access token: JWT with TTL
- Refresh token: persisted + revocable tokenId
- RBAC middleware: student, coaching_admin, platform_admin
- Strict input validation: express-validator
- Standard error envelope: success=false + message + details

## 6) IELTS Logic

- Section order fixed as Listening, Reading, Writing, Speaking
- Per-section duration configured in server constants
- Objective scoring for Listening/Reading using answer keys
- Raw-to-band conversion tables in score-utils
- Writing/Speaking responses stored for evaluator/manual workflow
- Overall band computed from section bands with half-band rounding

## 7) End-to-End Flows Implemented

### Student

- Register/Login securely
- Start generated mock session
- Save answers and mark questions for review
- Submit sections and final submit
- View result summary, history, and trend dashboard

### Coaching Center Admin

- Register as coaching_admin
- Auto-created institute profile
- Verify/link students by email
- Create and view discount codes
- View institute student list

### Platform Admin

- Login with seeded platform admin
- View platform overview metrics
- Create exams and question bank items
- Manage mock templates

## 8) Environment Variables

Backend example: lib/website_version/server/.env.example

Required:

- PORT
- NODE_ENV
- DB_URL
- DB_NAME
- JWT_ACCESS_SECRET
- JWT_REFRESH_SECRET
- JWT_ACCESS_TTL
- JWT_REFRESH_TTL_DAYS
- CLIENT_ORIGIN
- PLATFORM_ADMIN_SEED_EMAIL
- PLATFORM_ADMIN_SEED_PASSWORD

Frontend base URL:

- lib/utils/api_config.dart uses compile-time API_URL with fallback

## 9) Run Instructions

### Backend

1. cd lib/server
2. copy .env.example to .env and configure values
3. npm install
4. npm run seed
5. npm start

### Flutter App

1. flutter pub get
2. flutter run --dart-define=API_URL=http://localhost:8080

Android emulator example:

- flutter run --dart-define=API_URL=http://10.0.2.2:8080

## 10) Seed Accounts

After npm run seed:

- Platform admin: admin@g.com / Admin@12345 *(from .env PLATFORM_ADMIN_SEED_EMAIL/PASSWORD)*
- Teacher: teacher1@demo.com / Teacher@123
- Student: student1@demo.com / Student@123 *(Aisha Khan - 100 mock credits)*
- Coaching admin: coach1@demo.com / Coach@123 *(Bright IELTS Academy)*

For detailed demo flows and troubleshooting, see **[DEMO_SETUP.md](./DEMO_SETUP.md)**

## 11) Testing

### Backend

- npm test
- Includes health route and validation smoke tests

### Frontend

- flutter test
- Includes app boot smoke test

## 12) Manual QA Checklist

- Register/login with student and coaching admin
- Verify token persistence and logout
- Start mock, answer questions, mark for review, submit section
- Auto-submit path when timer expires
- Final submit and result summary
- Student history and trend loading
- Institute verify student and discount creation
- Admin create exam/question/template
- Unauthorized route access blocked by role middleware

## 13) Major Design Choices

- Kept migration in-place to reuse existing project base and avoid destructive rewrites
- Added versioned backend API under /api/v1 to isolate and scale safely
- Separated controllers/services/models for maintainability and testability
- Used response envelope for consistent frontend parsing and error handling
- Preserved realistic IELTS constraints while avoiding fake AI scoring claims for writing/speaking
