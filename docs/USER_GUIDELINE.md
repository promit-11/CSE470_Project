# IELTS Mock Test & Coaching Collaboration Platform

## 1. Title Page

**Document Title:** User Guideline / User Manual

**Product Name:** IELTS Mock Test & Coaching Collaboration Platform

**Project Type:** Flutter frontend + Node.js/Express backend + MongoDB database

**Prepared For:** End users, project report, viva, and operational reference

**Document Basis:** Current implementation review of the live V1 application flow, supporting documentation, and code-level audit performed in the repository

**Date:** 2026-04-19

---

## 2. Introduction

This application is an IELTS practice and collaboration platform built to let students take generated mock tests, receive objective scoring for Listening and Reading, submit Writing and Speaking responses for teacher review, and track progress over time. It also supports institute/coaching center workflows such as student verification and discount code handling, and platform admin workflows for question bank, exam, and template management.

The implementation is role-based. Different users see different screens and actions depending on whether they are a student, teacher, coaching/institute admin, or platform admin. The active production flow is the V1 API stack under `/api/v1`, and the Flutter app routes into the correct dashboard after authentication.

This manual explains what the app does in the present implementation, how users move through it, what data is saved, and where the current limits are.

---

## 3. System Overview

The system has three main layers:

- **Flutter frontend**: The mobile/web UI, built with Riverpod state management and reusable widgets for cards, buttons, score displays, and loading/error states.
- **Node.js + Express backend**: The API layer, implemented as a versioned `/api/v1` service with authentication, role checks, validation, scoring, analytics, and mock-session generation.
- **MongoDB**: The persistent store for users, student profiles, institutes, discount codes, questions, exams, mock templates, mock sessions, test history, refresh tokens, and analytics-related records.

The live architecture is intentionally split into two categories:

- **Active V1 stack**: The current runtime path used by the app.
- **Legacy compatibility files**: Older test/exam files kept in the repository for reference and safety, but not used by the live router flow.

At a user level, the platform solves four practical problems:

- Students can practice IELTS-style mock tests without manually assembling materials.
- Teachers can review subjective sections instead of forcing fake automated grading.
- Coaching centers can verify and support their students with discount workflows.
- Platform admins can manage the question bank, templates, and overall platform content.

---

## 4. User Roles

### Student

Students use the app to register, log in, start mock tests, answer questions, submit sections, view scores, review feedback, check history, and follow their performance trend.

### Teacher

Teacher accounts are part of the live implementation. They are routed either to an approval screen or to a teacher dashboard depending on approval status. Teachers handle Writing and Speaking review work and can request payout from accumulated reward credits.

### Institute / Coaching Center Admin

This role is implemented in the app as the coaching admin path. The live screen is the institute dashboard, and the role manages institute profile data, student verification, discount codes, coaching assignment requests, and coaching-owned content.

### Platform Admin

Platform admins manage app-owned exams, question bank entries, and mock templates. They also review teacher approvals, payout requests, and platform analytics.

### Role Summary

- **Student**: consume tests, view analytics, manage coaching assignment requests
- **Teacher**: review subjective responses and manage review/payout workflow
- **Coaching admin**: manage coaching profile, verify students, issue discount codes, and manage coaching-owned content
- **Platform admin**: manage platform-wide content and approvals

---

## 5. Authentication and Access

### Registration

The registration screen collects the basic account information required by the backend auth service. In the current implementation, the active registration flow supports the role-based user model used by the backend. For coaching admins, an institute profile is created as part of the backend workflow.

### Login

Login is email-and-password based. The Flutter login screen validates the form, sends credentials to the auth controller, and then routes the user based on the authenticated role.

### Logout

Logout clears the authenticated session in the app and returns the user to the login route.

### Role-Based Access

The splash screen checks stored authentication state first. If tokens are present, the app tries to restore the session and loads the authenticated user profile. If the token is valid, the app sends the user to the correct dashboard:

- Student -> Student Dashboard
- Teacher pending approval -> Teacher Pending Approval screen
- Approved teacher -> Teacher Dashboard
- Coaching admin -> Institute Dashboard
- Platform admin -> Admin Exam List / admin dashboard screen

If the stored token is expired, the backend refresh flow is attempted before the app gives up and returns to login.

### Security Behavior Visible to Users

- Passwords are not stored in plain text; the backend uses hashed passwords.
- The app uses JWT access and refresh tokens.
- Access is guarded by role checks on the backend and route selection on the frontend.

---

## 6. Student User Guide

### 6.1 Student Dashboard

The student dashboard is the main hub after login. It shows the student name, summary metrics, trend information, analysis cards, and action buttons.

What the student sees:

- A welcome section with the student’s name
- Performance overview cards
- Latest overall band, when available
- Pending Writing/Speaking review counts
- Band trend chart
- Section averages for Listening, Reading, Writing, Speaking
- Strengths and weaknesses chips
- Action buttons for starting a test, buying credits, requesting coaching assignment, and viewing archive/history

What the student can do:

- Start a new mock test or resume an existing one if the backend reports a resumable session
- Purchase mock access credits using the purchase flow exposed in the dashboard
- Request a coaching assignment from the institute workflow
- Open test history

What happens after an action:

- Starting a test opens the exam session and generates or resumes a mock session
- Purchase flow updates credit availability and reloads analytics
- Coaching assignment requests move into a pending workflow for institute review

### 6.2 Starting a Mock Test

The student taps the start/resume action from the dashboard. The app calls the mock-session generation flow through the backend.

What the system does:

- Creates or restores a mock session
- Loads the active template
- Selects questions from the active question bank
- Applies repetition-prevention logic using recent completed sessions
- Returns the session with all four IELTS sections in the fixed order

### 6.3 During the Test

The exam session screen shows one section at a time. The student can answer questions, mark items for review, move between questions, and submit the section when done.

Important behaviors:

- The section order is fixed: Listening, Reading, Writing, Speaking
- Each section has its own timer
- Answers are saved immediately through the backend flow
- Flagged questions are preserved as review markers
- The screen supports section progression and final submission

### 6.4 Result Summary

After submission, the result summary screen shows the outcome of the mock session.

What the student sees:

- Overall band information
- Section scores
- Pending review state for Writing/Speaking when not yet reviewed by a teacher
- Strengths and weaknesses, if present
- Visual score cards and feedback presentation

### 6.5 Test History

The archive screen lists previous completed tests in card form.

What the student sees:

- Test number and date/time
- Overall band or pending state
- Section score chips for Listening, Reading, Writing, and Speaking
- Status text that reflects reviewed or pending teacher review states

### 6.6 Progress Tracking

The dashboard analytics show:

- Total completed mocks
- Available credits or unlimited credit status
- Latest test result
- Trend line of overall band score
- Section averages
- Strengths and weaknesses

This gives the student a practical view of performance over time rather than just a one-time score.

---

## 7. Admin User Guide

### 7.1 Admin Dashboard

The platform admin area is the central control panel for app-owned content.

What the admin sees:

- Overview statistics
- Question lists and filters
- Exam list
- Template list
- Approval and review queues where applicable

### 7.2 Question Management

Admins can create, edit, and delete questions.

What matters in the current implementation:

- Questions are section-specific
- The section must be one of Listening, Reading, Writing, or Speaking
- Difficulty is used for mock-generation balance
- Questions can include title, content, options, answer key, explanation, media URL, and instruction fields

### 7.3 Exam and Template Management

Admins manage mock templates and exam definitions.

Template fields in the live implementation include:

- Template name
- Exam type, such as academic or general
- Difficulty distribution
- Per-section question counts
- Active/default status

### 7.4 Mock Generation Control

Admins influence how generated tests are built by controlling the question bank and template setup.

The generator:

- Uses the active template for the scope
- Randomly selects questions without replacement where possible
- Respects section order and section counts
- Attempts to avoid repeated questions from recent sessions

### 7.5 Analytics Overview

The platform admin overview shows aggregate platform data such as user counts, student counts, institute counts, completed sessions, and average band values.

This is useful for a quick platform health check rather than per-student review.

### 7.6 Teacher Approval and Payout Review

The platform admin workflow also includes teacher approval and payout queues.

The user-facing effect is that some teacher accounts cannot use the review dashboard until approved, and payout requests can be reviewed after enough reward credits accumulate.

---

## 8. Institute User Guide

### 8.1 Institute Profile Management

The coaching/institute dashboard lets the coaching admin maintain institute profile data.

Typical profile data includes:

- Institute name
- Description
- Address
- Phone

### 8.2 Student Verification

Coaching admins can verify or link students to the institute workflow.

Practical effect:

- A verified student is associated with the institute profile
- The association can be used for institute-level discount or collaboration workflows

### 8.3 Discount Code Generation

Coaching admins can create discount codes in the present implementation.

The discount code flow supports:

- Percentage-based discounts
- Fixed-value discounts
- Validity dates
- Usage limits
- Eligibility filtering by student

### 8.4 Discount Application Logic

Discounts are applied when the student purchases mock access.

What happens in practice:

- The purchase flow sends the code to the backend
- The backend validates eligibility, validity window, and remaining usage limit
- The backend calculates the final amount after discount
- The student dashboard reloads to reflect the new credit state

### 8.5 Coaching Assignment Requests

Students can request coaching assignment from the student side. The institute dashboard then handles those requests.

The coaching admin can review the queue and decide whether to accept or reject the request. Accepted requests link the student into the institute flow.

### 8.6 Coaching-Owned Content

The coaching dashboard also supports institute-owned content management in the current architecture. This is separate from app-owned content managed by platform admin.

---

## 9. Mock Test Section Guide

### 9.1 Listening

Goal: test comprehension of spoken English.

Inputs:

- Objective answers
- Question navigation and review flagging

User actions:

- Select or enter answers depending on question type
- Move between questions
- Mark items for review
- Submit the section when finished

Timer rule:

- 30 minutes in the active implementation

Submission rule:

- When submitted, the backend checks answers against the answer key and calculates a raw score

Scoring behavior:

- Automatic and objective
- Raw score is converted into an IELTS band

### 9.2 Reading

Goal: test comprehension of written English texts.

Inputs:

- Objective answers
- Review flags

Timer rule:

- 60 minutes

Submission rule:

- Objective marking against the stored answer key

Scoring behavior:

- Automatic and objective
- Raw score is converted into an IELTS band

### 9.3 Writing

Goal: capture a written response for manual evaluation.

Inputs:

- Text responses

Timer rule:

- 60 minutes

Submission rule:

- The response is saved
- The section is marked for teacher review

Scoring behavior:

- Not automatically scored in the current implementation
- The current live flow stores the response and uses teacher review later

### 9.4 Speaking

Goal: capture speaking-related responses for manual evaluation.

Inputs:

- Text-based response capture in the current implementation

Timer rule:

- 15 minutes

Submission rule:

- The response is saved for later review

Scoring behavior:

- Not automatically scored in the current implementation
- Teacher review determines the final band later

### 9.5 Question Navigation and Review Flags

Across the exam screen, the student can:

- Jump between questions
- Mark questions for review
- Return to flagged questions before submission

These are local session aids and do not change the section score by themselves.

### 9.6 Auto-Submit and Final Submit

If a section timer expires, the section is auto-submitted.

Final submit completes the session lifecycle and stores the completed outcome so it can appear in history and analytics.

---

## 10. Scoring and Result Processing

### Listening and Reading

These are objectively scored.

How the score is produced:

- The backend compares user answers with the answer key
- A raw score is calculated from correct responses
- The raw score is converted to an IELTS band using the scoring table

These scores are exact in the sense that they are determined by answer correctness and the conversion table.

### Writing and Speaking

These are subjectively evaluated.

How the score is handled in the current implementation:

- Responses are saved during the mock flow
- The section is marked as pending teacher review
- Teacher review later supplies band and rubric details

These scores are not automatically estimated by the live backend flow in the present implementation. They depend on the review workflow.

### Overall Band

The overall band summary is generated from the section bands that are available at that time.

Practical user effect:

- If Writing or Speaking is still pending, the UI indicates that the overall band is not final
- If all sections are reviewed, the summary can show a complete overall band

### Exact vs Estimated

- **Exact**: Listening and Reading, because they use answer matching and band conversion
- **Manual / reviewed**: Writing and Speaking
- **Derived summary**: Overall band and dashboard averages, based on the data available from the session and review records

---

## 11. Analytics and Performance Tracking

### What Data Is Saved

The implementation stores data that supports history and analytics, including:

- Completed mock sessions
- Section scores
- Overall band values
- Completion timestamps
- Pending review states
- Strengths and weaknesses
- Trend points for dashboard charts

### How History Is Shown

The student archive shows completed test cards with score chips and status labels. The dashboard uses a more summary-oriented view to show the latest result, trend, and section averages.

### Strengths and Weaknesses

The analytics model includes strengths and weaknesses lists. These are rendered as chips or grouped lists depending on the screen.

### Trend Charts

The dashboard shows an overall-band trend chart. In the current implementation, the chart is based on overall band values rather than full section trend breakdowns.

### Section Feedback

Section feedback is displayed when available, especially in the result summary and analytics-related screens.

---

## 12. Dynamic Test Generation

### How Tests Are Created

The mock-session generator builds a complete IELTS mock session from the question bank and the active mock template.

### Section Structure

The generated test always follows the standard IELTS order:

1. Listening
2. Reading
3. Writing
4. Speaking

### Randomness

Questions are selected randomly from the active question pool, but the algorithm does not simply pick at random from all questions.

It uses the template and the question metadata to keep the section structure valid and the difficulty mix controlled.

### Repetition Prevention

The generator checks recent completed sessions and tries to avoid reusing the same questions too often.

Current behavior:

- Recent session history is used as the repetition source
- The active implementation uses a capped repeat rate when fresh questions are limited
- If the bank is too small, the generator falls back so the session can still be built

### What the Student Experiences

The student sees a complete mock test that feels structured and comparable to IELTS rather than a fixed static question sheet.

---

## 13. Screen-by-Screen Guide

### Splash Screen

Purpose: restore the user session and choose the next route.

What the user sees: a loading state while the app checks stored auth state.

Actions: none.

Outcome: the app routes to the correct screen based on the authenticated role.

### Login Screen

Purpose: authenticate the user.

What the user sees: email and password inputs, error message area, sign-in button, and a link to registration.

Actions: enter credentials, submit form, go to registration if needed.

Outcome: successful login stores auth state and routes to the proper dashboard.

### Register Screen

Purpose: create a new account.

What the user sees: registration form and role selection.

Actions: enter name, email, password, choose role, optionally enter institute data when relevant.

Outcome: the account is created and the user is guided back to login or into the role workflow described by the backend.

### Student Dashboard

Purpose: main student landing page.

What the user sees: analytics cards, chart, section averages, pending review indicators, and action buttons.

Actions: start/resume mock test, buy credits, request coaching assignment, open history.

Outcome: navigates to the relevant flow or refreshes analytics after data changes.

### Exam Session Screen

Purpose: conduct the mock test.

What the user sees: current section, current question, timer, navigation controls, flagged-question support, and submission controls.

Actions: answer questions, flag questions, move through the paper, submit section, final submit.

Outcome: answers are saved, sections progress, and the final session data is stored.

### Result Summary Screen

Purpose: show the mock result after completion.

What the user sees: overall band, section bands, status indicators, and feedback-related cards.

Actions: review the outcome and continue to history or dashboard.

Outcome: the user gets a readable summary of what is final and what is still pending review.

### Student Archive Screen

Purpose: show past tests.

What the user sees: a list of completed tests with date/time, band values, and review status.

Actions: refresh history, return to dashboard.

Outcome: history remains a persistent record of completed sessions.

### Institute Dashboard Screen

Purpose: coaching-admin control panel.

What the user sees: institute profile and operational queues for students, discount codes, and coaching-owned content.

Actions: update profile, verify students, manage requests, issue discounts.

Outcome: institute-related workflows are updated in the backend.

### Admin Exam List / Platform Admin Screen

Purpose: platform-wide content administration.

What the user sees: exam and question data, templates, and analytics/management queues.

Actions: create or update questions, exams, and templates; review approvals and analytics.

Outcome: platform content and configuration are updated.

### Teacher Pending Approval Screen

Purpose: show that the teacher account cannot yet enter the review dashboard.

What the user sees: pending approval state.

Actions: none beyond waiting for approval.

Outcome: approved teachers can later reach the teacher dashboard.

### Teacher Dashboard and Teacher Review Detail Screens

Purpose: manage subjective review queues.

What the user sees: pending/claimed/reviewed work queues and review details.

Actions: claim work, enter rubric scores, submit review, request payout.

Outcome: Writing and Speaking results become available to students after review.

---

## 14. End-to-End User Workflows

### 14.1 New Student Registration to First Mock Test

1. The student registers.
2. The student logs in.
3. The app routes to the student dashboard.
4. The student starts a mock test.
5. The test generator builds a session from the active template and question bank.
6. The student answers each section in order.
7. The student submits sections and then final submit.
8. The result summary appears.
9. The test is stored in history and analytics update on the dashboard.

### 14.2 Returning Student Checking History

1. The student logs in.
2. The dashboard loads the latest analytics.
3. The student opens the archive screen.
4. Past tests are shown as cards with scores and pending/review states.
5. The student returns to the dashboard or starts a new mock.

### 14.3 Admin Creating or Managing Questions

1. The platform admin logs in.
2. The admin opens the question management area.
3. The admin creates a question and selects a section, difficulty, and content type.
4. The backend validates the payload.
5. The question is saved and becomes available for mock generation if active.

### 14.4 Admin Creating or Managing Templates

1. The admin opens template management.
2. The admin sets the template name, exam type, section counts, and difficulty distribution.
3. The backend validates the template.
4. The template becomes usable by the mock generator.

### 14.5 Institute Admin Verifying Students and Creating Discount Codes

1. The coaching admin logs in.
2. The institute dashboard loads the profile and request queues.
3. The admin verifies a student or reviews a coaching assignment request.
4. The admin creates a discount code when needed.
5. The student uses the code during purchase flow and the backend applies the discount.

### 14.6 Teacher Reviewing Subjective Sections

1. A teacher logs in.
2. If not approved, the teacher sees the approval screen.
3. If approved, the teacher opens the dashboard.
4. The teacher claims a pending review.
5. The teacher enters rubric scores and comments.
6. The review is submitted.
7. The student’s pending Writing/Speaking result becomes available.

---

## 15. Limitations and Current Gaps

The current implementation is functional, but some parts are not fully automated.

### Confirmed limitations in the live codebase

- Writing and Speaking are not automatically scored by the backend in the same way as Listening and Reading.
- There is no audio capture flow for Speaking in the present implementation.
- Student-side template selection is not exposed; the active template is chosen by the backend.
- The trend chart focuses on overall band, not full per-section trend series.
- Purchase and discount logic are implemented as application flows, but there is no visible payment gateway integration in the audited code.
- Some legacy controllers, services, and models remain in the repository for compatibility, even though the live V1 router does not use them.

### Practical consequences

- Students may see Writing/Speaking as pending until a teacher review is completed.
- A very small question bank can still force reuse even though repetition prevention is present.
- Some older files in the tree can be misleading if read without the architecture notes.

---

## 16. Conclusion

This platform is a role-based IELTS practice system that supports live mock testing, teacher-reviewed subjective scoring, coaching collaboration, and platform administration. In the current implementation, it is strongest in its core mock-session generation, student dashboard analytics, and role-based routing. The system is intentionally designed to keep objective scoring automatic while leaving subjective sections for teacher review.

For end users, the most important workflow is straightforward: sign in, take a generated mock test, review the result, and track progress over time. For coaches and admins, the system provides the tools needed to support student verification, content management, and platform oversight.

---

## Implementation Reality Notes

This section records what is fully implemented, partially implemented, legacy, or estimated based on the audited code.

### Fully implemented

- Role-based routing from splash/login to the correct dashboard
- Student mock-session flow with section order, timers, answer saving, review flags, section submit, and final submit
- Objective scoring for Listening and Reading
- Student dashboard analytics, trend rendering, and history display
- Platform admin question, exam, and template management
- Institute/coaching admin profile, student verification, and discount code workflow
- Dynamic mock generation with template-driven structure and repetition reduction
- Teacher review workflow for subjective sections

### Partially implemented

- Writing and Speaking evaluation are stored and routed for review, but not automatically scored in the same way as objective sections
- Payment-related purchase flow is modeled in the app, but no full external payment gateway was visible in the audited implementation
- Some analytics are summary-driven rather than exhaustive per-question or per-skill reporting

### Legacy or compatibility-only

- Older test/exam controllers, services, models, and routes are still present in the repository
- These legacy files are not part of the live `/api/v1` runtime path
- They remain in place for safety and transition continuity

### Estimated only if needed

- Any external payment settlement behavior beyond the in-app discount/purchase flow
- Any future teacher workflow extensions not present in the current code

### Bottom line

The live V1 application is real and usable for the core IELTS mock-test collaboration flow, but subjective scoring remains teacher-driven rather than automated, and legacy files still exist as a compatibility layer.