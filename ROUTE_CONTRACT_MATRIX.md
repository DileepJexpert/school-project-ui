# Authoritative Route Contract Matrix: FastAPI to Flutter

Authoritative API contract extracted from `app.routes`, OpenAPI specification, AST inspection of handler and helper source code, and Flutter Dio client calls. Total Endpoint Methods: **170**.

## Security & Access Invariants
- **School Login (`POST /api/auth/login`):** Public endpoint, but **Required `X-Tenant-ID`** header enforced via `tenant_id` dependency. Raises `401` on invalid credentials and `403` if the tenant school is inactive (via `app.auth.authenticate`).
- **Platform Login (`POST /platform/auth/login`):** Public endpoint in Platform scope. Raises `401` on invalid credentials and `403` if user inactive.
- **Site Content Updates (`PUT /api/site-content`):** Requires Bearer token + **`SUPER_ADMIN` or `SCHOOL_ADMIN`** role.
- **Contact Enquiries (`GET /api/contact/enquiries`):** Requires Bearer token + **`SUPER_ADMIN` or `SCHOOL_ADMIN`** role.
- **Platform Endpoints (`/platform/*`):** Gated by `SUPER_ADMIN` platform authorization.
- **School API Endpoints (`/api/*`):** Gated by tenant scoping and granular RBAC permissions.

## Contract Resolution Status
- **Documented Pydantic Response Models:** 60 endpoints.
- **Unresolved Untyped Dict Responses:** 110 endpoints (detailed in inventory below for Phase 2/4 typing).

## Route Matrix

| Method | Path | Module | Auth | Role / Permission | Tenant Scope | Request Contract | Response Contract | Status Codes | Flutter Callers |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/academic-years/rollover` | `rollover` | Bearer Token | Permission: students:write | Required (X-Tenant-ID) | `RolloverInput`<br>Params: Idempotency-Key (header, string, req) | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/academic-years/rollover/{run_id}` | `rollover` | Bearer Token | Permission: students:read | Required (X-Tenant-ID) | `(None)`<br>Params: run_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/ai-config` | `ai` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/ai_config_api_service.dart:8` |
| `PUT` | `/api/ai-config` | `ai` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `AiConfigInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/ai_config_api_service.dart:15` |
| `GET` | `/api/ai-config/usage-report` | `ai` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)`<br>Params: from (query, string, req), to (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/ai_config_api_service.dart:22` |
| `POST` | `/api/ai/chat` | `ai` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `AiChatInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/ai_api_service.dart:6` |
| `GET` | `/api/ai/conversations` | `ai` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/ai_api_service.dart:12` |
| `GET` | `/api/ai/conversations/{conversation_id}` | `ai` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)`<br>Params: conversation_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/ai_api_service.dart:18` |
| `GET` | `/api/ai/usage` | `ai` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/ai_api_service.dart:24` |
| `GET` | `/api/attendance/class/{class_name}` | `attendance` | Bearer Token | Permission: attendance:read | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req), date (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/attendance_api_service.dart:30` |
| `GET` | `/api/attendance/class/{class_name}/range` | `attendance` | Bearer Token | Permission: attendance:read | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req), from (query, string, req), to (query, string, req), academicYear (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/attendance_api_service.dart:66` |
| `POST` | `/api/attendance/mark` | `attendance` | Bearer Token | Permission: attendance:write | Required (X-Tenant-ID) | `AttendanceBulkInput` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/attendance_api_service.dart:15` |
| `GET` | `/api/attendance/student/{student_id}` | `attendance` | Bearer Token | Permission: attendance:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), from (query, string, req), to (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/attendance_api_service.dart:42` |
| `GET` | `/api/attendance/student/{student_id}/summary` | `attendance` | Bearer Token | Permission: attendance:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), academicYear (query, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/attendance_api_service.dart:54` |
| `DELETE` | `/api/attendance/{record_id}` | `attendance` | Bearer Token | Permission: attendance:write | Required (X-Tenant-ID) | `(None)`<br>Params: record_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/attendance_api_service.dart:76` |
| `POST` | `/api/auth/login` | `auth` | Public | Public (Unauthenticated) | Required (X-Tenant-ID) | `LoginInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `POST` | `/api/auth/logout` | `auth` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)`<br>Params: Authorization (header, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/auth_service.dart:124` |
| `POST` | `/api/auth/refresh` | `auth` | Public | Public (Unauthenticated) | None | `RefreshInput` | `object` <br>*(untyped dict)* | 200, 401, 422 | `lib/services/auth_service.dart:102` |
| `GET` | `/api/certificates` | `school_workflows` | Bearer Token | Permission: certificates:read | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/certificate_api_service.dart:24` |
| `POST` | `/api/certificates/generate` | `school_workflows` | Bearer Token | Permission: certificates:write | Required (X-Tenant-ID) | `CertificateInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/certificate_api_service.dart:8` |
| `GET` | `/api/certificates/student/{student_id}` | `school_workflows` | Bearer Token | Permission: certificates:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/certificate_api_service.dart:14` |
| `GET` | `/api/certificates/type/{certificate_type}` | `school_workflows` | Bearer Token | Permission: certificates:read | Required (X-Tenant-ID) | `(None)`<br>Params: certificate_type (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/certificate_api_service.dart:19` |
| `GET` | `/api/chat/rooms` | `chat` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)`<br>Params: userId (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/chat_api_service.dart:14` |
| `POST` | `/api/chat/rooms` | `chat` | Bearer Token | STUDENT, PARENT | Required (X-Tenant-ID) | `ChatRoomInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/chat_api_service.dart:29` |
| `GET` | `/api/chat/rooms/{room_id}/messages` | `chat` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)`<br>Params: room_id (path, string, req), page (query, integer, opt), size (query, integer, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/chat_api_service.dart:42` |
| `POST` | `/api/chat/rooms/{room_id}/messages` | `chat` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `ChatMessageInput`<br>Params: room_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/chat_api_service.dart:53` |
| `PUT` | `/api/chat/rooms/{room_id}/read` | `chat` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `object`<br>Params: room_id (path, string, req), userId (query, any, opt) | `(None)` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/chat_api_service.dart:59` |
| `GET` | `/api/contact/enquiries` | `public` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `POST` | `/api/contact/enquiry` | `public` | Public | Public (Unauthenticated) | Optional / Header (X-Tenant-ID) | `ContactEnquiryInput` | `object` <br>*(untyped dict)* | 201, 400, 422 | `lib/features/contact/contact_page.dart:43` |
| `GET` | `/api/discipline` | `school_workflows` | Bearer Token | Permission: discipline:read | Required (X-Tenant-ID) | `(None)`<br>Params: className (query, any, opt), severity (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/discipline_api_service.dart:11` |
| `POST` | `/api/discipline` | `school_workflows` | Bearer Token | Permission: discipline:write | Required (X-Tenant-ID) | `IncidentInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/discipline_api_service.dart:20` |
| `GET` | `/api/discipline/student/{student_id}` | `school_workflows` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/discipline_api_service.dart:25` |
| `GET` | `/api/discipline/summary` | `school_workflows` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/discipline_api_service.dart:39` |
| `PUT` | `/api/discipline/{incident_id}/resolve` | `school_workflows` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `IncidentResolutionInput`<br>Params: incident_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/discipline_api_service.dart:31` |
| `GET` | `/api/expenses` | `expenses` | Bearer Token | Permission: expenses:read | Required (X-Tenant-ID) | `(None)`<br>Params: from (query, any, opt), to (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:107` |
| `POST` | `/api/expenses` | `expenses` | Bearer Token | Permission: expenses:write | Required (X-Tenant-ID) | `ExpenseInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:117` |
| `DELETE` | `/api/expenses/{expense_id}` | `expenses` | Bearer Token | Permission: expenses:write | Required (X-Tenant-ID) | `(None)`<br>Params: expense_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:121` |
| `POST` | `/api/fees/collect` | `payments` | Bearer Token | Permission: fees:write | Required (X-Tenant-ID) | `FeePaymentInput`<br>Params: Idempotency-Key (header, any, opt) | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:35` |
| `GET` | `/api/fees/dues` | `payments` | Bearer Token | Permission: fees:read | Required (X-Tenant-ID) | `(None)`<br>Params: academicYear (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:41` |
| `GET` | `/api/fees/payments` | `payments` | Bearer Token | Permission: fees:read | Required (X-Tenant-ID) | `(None)`<br>Params: academicYear (query, any, opt), studentId (query, any, opt), status (query, string, opt), page (query, integer, opt), size (query, integer, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/fees/payments/{payment_id}` | `payments` | Bearer Token | Permission: fees:read | Required (X-Tenant-ID) | `(None)`<br>Params: payment_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `POST` | `/api/fees/payments/{payment_id}/void` | `payments` | Bearer Token | Permission: fees:write | Required (X-Tenant-ID) | `VoidPaymentInput`<br>Params: payment_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/fees/search` | `payments` | Bearer Token | Permission: fees:read | Required (X-Tenant-ID) | `(None)`<br>Params: name (query, string, opt), className (query, any, opt), rollNumber (query, any, opt), academicYear (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:27` |
| `GET` | `/api/feestructures` | `fees` | Bearer Token | Permission: fees:read | Required (X-Tenant-ID) | `(None)`<br>Params: year (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:50` |
| `POST` | `/api/feestructures` | `fees` | Bearer Token | Permission: fees:write | Required (X-Tenant-ID) | `List[FeeStructureInput]` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:61`<br>`lib/services/fee_api_service.dart:66` |
| `DELETE` | `/api/feestructures/{structure_id}` | `fees` | Bearer Token | Permission: fees:write | Required (X-Tenant-ID) | `(None)`<br>Params: structure_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:70` |
| `GET` | `/api/homework` | `school_workflows` | Bearer Token | Permission: homework:read | Required (X-Tenant-ID) | `(None)`<br>Params: className (query, any, opt), academicYear (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/homework_api_service.dart:18` |
| `POST` | `/api/homework` | `school_workflows` | Bearer Token | Permission: homework:write | Required (X-Tenant-ID) | `HomeworkInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/homework_api_service.dart:28` |
| `DELETE` | `/api/homework/{homework_id}` | `school_workflows` | Bearer Token | TEACHER | Required (X-Tenant-ID) | `(None)`<br>Params: homework_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/homework_api_service.dart:41` |
| `GET` | `/api/homework/{homework_id}` | `school_workflows` | Bearer Token | STUDENT, PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: homework_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/homework/{homework_id}` | `school_workflows` | Bearer Token | TEACHER | Required (X-Tenant-ID) | `HomeworkInput`<br>Params: homework_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/homework_api_service.dart:35` |
| `GET` | `/api/leave` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: status (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:44` |
| `POST` | `/api/leave/apply` | `hr` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN, TEACHER, ACCOUNTANT | Required (X-Tenant-ID) | `LeaveInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:53` |
| `GET` | `/api/leave/staff/{staff_id}` | `hr` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)`<br>Params: staff_id (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `DELETE` | `/api/leave/{leave_id}` | `hr` | Bearer Token | Permission: staff:write | Required (X-Tenant-ID) | `(None)`<br>Params: leave_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/leave/{leave_id}/approve` | `hr` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `LeaveDecisionInput`<br>Params: leave_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:59` |
| `GET` | `/api/master-data` | `master_data` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)`<br>Params: academicYear (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/features/admin/screens/settings_screen.dart:45` |
| `GET` | `/api/master-data/class-subjects` | `master_data` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)`<br>Params: className (query, string, req), academicYear (query, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/master-data/class-subjects` | `master_data` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `ClassSubjectsInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/master-data/subjects` | `master_data` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/master-data/subjects` | `master_data` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `SchoolSubjectInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/notifications` | `notifications` | Bearer Token | Permission: notifications:read | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/notification_api_service.dart:8` |
| `POST` | `/api/notifications` | `notifications` | Bearer Token | Permission: notifications:write | Required (X-Tenant-ID) | `NotificationInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/notification_api_service.dart:17` |
| `GET` | `/api/notifications/class/{class_name}` | `notifications` | Bearer Token | STUDENT, PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/notifications/student/{student_id}` | `notifications` | Bearer Token | STUDENT, PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), class_name (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/notifications/type/{notice_type}` | `notifications` | Bearer Token | Permission: notifications:read | Required (X-Tenant-ID) | `(None)`<br>Params: notice_type (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/notification_api_service.dart:39` |
| `DELETE` | `/api/notifications/{notice_id}` | `notifications` | Bearer Token | TEACHER | Required (X-Tenant-ID) | `(None)`<br>Params: notice_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/notification_api_service.dart:34` |
| `PUT` | `/api/notifications/{notice_id}` | `notifications` | Bearer Token | TEACHER | Required (X-Tenant-ID) | `NotificationInput`<br>Params: notice_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/notification_api_service.dart:24` |
| `PUT` | `/api/notifications/{notice_id}/read` | `notifications` | Bearer Token | Any Authenticated (Own notification) | Required (X-Tenant-ID) | `(None)`<br>Params: notice_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/notification_api_service.dart:29` |
| `GET` | `/api/parent/child/{student_id}/attendance` | `portals` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), month (query, any, opt), year (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/parent_api_service.dart:18` |
| `GET` | `/api/parent/child/{student_id}/attendance/summary` | `portals` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), academicYear (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/parent_api_service.dart:29` |
| `GET` | `/api/parent/child/{student_id}/fees` | `portals` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/parent_api_service.dart:47` |
| `GET` | `/api/parent/child/{student_id}/results` | `portals` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), academicYear (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/parent_api_service.dart:38` |
| `GET` | `/api/parent/child/{student_id}/timetable` | `portals` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/parent_api_service.dart:53` |
| `GET` | `/api/parent/dashboard` | `portals` | Bearer Token | PARENT | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403 | `lib/services/parent_api_service.dart:8` |
| `GET` | `/api/reports/fees/report-summary` | `reports` | Bearer Token | Permission: reports:read | Required (X-Tenant-ID) | `(None)`<br>Params: startDate (query, any, opt), endDate (query, any, opt), className (query, any, opt), paymentMode (query, any, opt), page (query, integer, opt), size (query, integer, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:92` |
| `GET` | `/api/reports/school-summary` | `reports` | Bearer Token | Permission: reports:read | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:75` |
| `GET` | `/api/results` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: rollNumber (query, string, req), className (query, string, req), academicYear (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/features/results/results_page.dart:50` |
| `POST` | `/api/results/bulk` | `results` | Bearer Token | Permission: results:write | Required (X-Tenant-ID) | `ResultBulkInput` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:38` |
| `GET` | `/api/results/class/{class_name}/analytics` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req), year (query, string, req), examType (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:94` |
| `GET` | `/api/results/class/{class_name}/exam/{exam_type}` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req), exam_type (path, string, req), year (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:56` |
| `POST` | `/api/results/coscholastic` | `results` | Bearer Token | Permission: results:write | Required (X-Tenant-ID) | `CoscholasticInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:164` |
| `GET` | `/api/results/coscholastic/student/{student_id}` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), year (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:151` |
| `GET` | `/api/results/exam-config` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: year (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:134` |
| `POST` | `/api/results/exam-config` | `results` | Bearer Token | Permission: results:write | Required (X-Tenant-ID) | `ExamConfigInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:143` |
| `GET` | `/api/results/grading-policy` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: year (query, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/results/grading-policy` | `results` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `GradingPolicyInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/results/publish` | `results` | Bearer Token | Permission: results:write | Required (X-Tenant-ID) | `(None)`<br>Params: className (query, string, req), examType (query, string, req), year (query, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:108` |
| `GET` | `/api/results/student/{student_id}` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), year (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:80` |
| `GET` | `/api/results/student/{student_id}/report` | `results` | Bearer Token | Permission: results:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), year (query, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:69` |
| `DELETE` | `/api/results/{result_id}` | `results` | Bearer Token | Permission: results:write | Required (X-Tenant-ID) | `(None)`<br>Params: result_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/result_api_service.dart:128` |
| `PUT` | `/api/results/{result_id}` | `results` | Bearer Token | Permission: results:write | Required (X-Tenant-ID) | `ResultUpdateInput`<br>Params: result_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/result_api_service.dart:108`<br>`lib/services/result_api_service.dart:123` |
| `GET` | `/api/salary` | `hr` | Bearer Token | Permission: payroll:read | Required (X-Tenant-ID) | `(None)`<br>Params: month (query, integer, req), year (query, integer, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:71` |
| `POST` | `/api/salary/generate` | `hr` | Bearer Token | Permission: payroll:write | Required (X-Tenant-ID) | `SalaryGenerateInput` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:80` |
| `GET` | `/api/salary/staff/{staff_id}` | `hr` | Bearer Token | Permission: payroll:read | Required (X-Tenant-ID) | `(None)`<br>Params: staff_id (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/salary/{salary_id}/pay` | `hr` | Bearer Token | Permission: payroll:write | Required (X-Tenant-ID) | `object`<br>Params: salary_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:88` |
| `GET` | `/api/school/profile` | `school_profile` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/features/admin/screens/settings_screen.dart:43` |
| `PUT` | `/api/school/profile` | `school_profile` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `SchoolProfileInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/features/admin/screens/settings_screen.dart:113` |
| `GET` | `/api/site-content` | `site_content` | Public | Public (Unauthenticated) | Optional / Header (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 422 | `lib/models/school_data.dart:254` |
| `PUT` | `/api/site-content` | `site_content` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `SiteContentInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/staff` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: department (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:13` |
| `POST` | `/api/staff` | `hr` | Bearer Token | Permission: staff:write | Required (X-Tenant-ID) | `StaffInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:24` |
| `GET` | `/api/staff-attendance` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: date (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/staff-attendance/date` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: date (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:96` |
| `GET` | `/api/staff-attendance/department/{department}` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: department (path, string, req), date (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `POST` | `/api/staff-attendance/mark` | `hr` | Bearer Token | Permission: staff:write | Required (X-Tenant-ID) | `List[StaffAttendanceInput]` | `List[object]` | 201, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:105` |
| `GET` | `/api/staff-attendance/staff/{staff_id}` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: staff_id (path, string, req), from (query, string, req), to (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/staff/dashboard` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:8` |
| `GET` | `/api/staff/search` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: name (query, string, opt) | `List[object]` | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `DELETE` | `/api/staff/{staff_id}` | `hr` | Bearer Token | Permission: staff:write | Required (X-Tenant-ID) | `(None)`<br>Params: staff_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:35` |
| `GET` | `/api/staff/{staff_id}` | `hr` | Bearer Token | Permission: staff:read | Required (X-Tenant-ID) | `(None)`<br>Params: staff_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:8`<br>`lib/services/staff_api_service.dart:18` |
| `PUT` | `/api/staff/{staff_id}` | `hr` | Bearer Token | Permission: staff:write | Required (X-Tenant-ID) | `StaffInput`<br>Params: staff_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/staff_api_service.dart:30` |
| `GET` | `/api/student-fee-profiles/{student_id}` | `fees` | Bearer Token | Permission: fees:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req), academicYear (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/fee_api_service.dart:13` |
| `GET` | `/api/student-portal/attendance` | `portals` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)`<br>Params: month (query, any, opt), year (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/student_portal_api_service.dart:18` |
| `GET` | `/api/student-portal/attendance/summary` | `portals` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)`<br>Params: academicYear (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/student_portal_api_service.dart:27` |
| `GET` | `/api/student-portal/dashboard` | `portals` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403 | `lib/services/student_portal_api_service.dart:8` |
| `GET` | `/api/student-portal/fees` | `portals` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403 | `lib/services/student_portal_api_service.dart:51` |
| `GET` | `/api/student-portal/homework` | `school_workflows` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/homework_api_service.dart:8` |
| `GET` | `/api/student-portal/results` | `portals` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)`<br>Params: academicYear (query, any, opt) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/student_portal_api_service.dart:36` |
| `GET` | `/api/student-portal/timetable` | `portals` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403 | `lib/services/student_portal_api_service.dart:45` |
| `GET` | `/api/student-portal/videos` | `videos` | Bearer Token | STUDENT | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/video_api_service.dart:26` |
| `GET` | `/api/students` | `students` | Bearer Token | Permission: students:read | Required (X-Tenant-ID) | `(None)`<br>Params: className (query, any, opt), academicYear (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/admission_api_service.dart:9`<br>`lib/services/result_api_service.dart:12`<br>*(+1 more)* |
| `POST` | `/api/students/add` | `students` | Bearer Token | Permission: students:write | Required (X-Tenant-ID) | `StudentInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/admission_api_service.dart:21` |
| `POST` | `/api/students/enquiry` | `students` | Bearer Token | Permission: students:write | Required (X-Tenant-ID) | `StudentInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/admission_api_service.dart:27` |
| `GET` | `/api/students/search` | `students` | Bearer Token | Permission: students:read | Required (X-Tenant-ID) | `(None)`<br>Params: name (query, string, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/student_api_service.dart:21` |
| `DELETE` | `/api/students/{student_id}` | `students` | Bearer Token | Permission: students:write | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/admission_api_service.dart:35` |
| `GET` | `/api/students/{student_id}` | `students` | Bearer Token | Permission: students:read | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/admission_api_service.dart:16`<br>`lib/services/student_api_service.dart:15`<br>*(+1 more)* |
| `PUT` | `/api/students/{student_id}` | `students` | Bearer Token | Permission: students:write | Required (X-Tenant-ID) | `StudentInput`<br>Params: student_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/admission_api_service.dart:31` |
| `POST` | `/api/timetable` | `timetable` | Bearer Token | Permission: timetable:write | Required (X-Tenant-ID) | `TimetableDayInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/timetable_api_service.dart:22` |
| `DELETE` | `/api/timetable/entry/{day_id}` | `timetable` | Bearer Token | Permission: timetable:write | Required (X-Tenant-ID) | `(None)`<br>Params: day_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/timetable_api_service.dart:28` |
| `DELETE` | `/api/timetable/{class_name}` | `timetable` | Bearer Token | Permission: timetable:write | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req), academicYear (query, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/timetable_api_service.dart:34` |
| `GET` | `/api/timetable/{class_name}` | `timetable` | Bearer Token | Permission: timetable:read | Required (X-Tenant-ID) | `(None)`<br>Params: class_name (path, string, req), academicYear (query, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/timetable_api_service.dart:10` |
| `GET` | `/api/transport/assignments` | `transport` | Bearer Token | Permission: transport:read | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:61` |
| `POST` | `/api/transport/assignments` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `TransportAssignmentInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:92` |
| `GET` | `/api/transport/assignments/bus/{bus_id}` | `transport` | Bearer Token | Permission: transport:read | Required (X-Tenant-ID) | `(None)`<br>Params: bus_id (path, string, req) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:70` |
| `GET` | `/api/transport/assignments/student/{student_id}` | `transport` | Bearer Token | STUDENT, PARENT | Required (X-Tenant-ID) | `(None)`<br>Params: student_id (path, string, req) | `(None)` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:81` |
| `DELETE` | `/api/transport/assignments/{assignment_id}` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `(None)`<br>Params: assignment_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:97` |
| `GET` | `/api/transport/buses` | `transport` | Bearer Token | Permission: transport:read | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:13` |
| `POST` | `/api/transport/buses` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `BusInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:20` |
| `DELETE` | `/api/transport/buses/{bus_id}` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `(None)`<br>Params: bus_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:31` |
| `PUT` | `/api/transport/buses/{bus_id}` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `BusInput`<br>Params: bus_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:26` |
| `GET` | `/api/transport/routes` | `transport` | Bearer Token | Permission: transport:read | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:37` |
| `POST` | `/api/transport/routes` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `TransportRouteInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:44` |
| `DELETE` | `/api/transport/routes/{route_id}` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `(None)`<br>Params: route_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:55` |
| `PUT` | `/api/transport/routes/{route_id}` | `transport` | Bearer Token | Permission: transport:write | Required (X-Tenant-ID) | `TransportRouteInput`<br>Params: route_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:50` |
| `GET` | `/api/transport/stats` | `transport` | Bearer Token | Permission: transport:read | Required (X-Tenant-ID) | `(None)` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/services/transport_api_service.dart:103` |
| `GET` | `/api/users` | `users` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN, PARENT, STUDENT, TEACHER | Required (X-Tenant-ID) | `(None)` | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/chat_api_service.dart:8`<br>`lib/features/admin/screens/user_management_screen.dart:37` |
| `POST` | `/api/users` | `users` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `UserInput` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/features/admin/screens/user_management_screen.dart:148` |
| `POST` | `/api/users/change-password` | `users` | Bearer Token | Any Authenticated (Own User) | Required (X-Tenant-ID) | `ChangePasswordInput` | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/features/admin/screens/settings_screen.dart:260` |
| `DELETE` | `/api/users/{user_id}` | `users` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)`<br>Params: user_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/features/admin/screens/user_management_screen.dart:194` |
| `GET` | `/api/users/{user_id}` | `users` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `(None)`<br>Params: user_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/api/users/{user_id}` | `users` | Bearer Token | SUPER_ADMIN, SCHOOL_ADMIN | Required (X-Tenant-ID) | `UserInput`<br>Params: user_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | `lib/features/admin/screens/user_management_screen.dart:150` |
| `GET` | `/api/videos` | `videos` | Bearer Token | Permission: videos:read | Required (X-Tenant-ID) | `(None)`<br>Params: className (query, any, opt), subject (query, any, opt) | `List[object]` | 200, 400, 401, 403, 422 | `lib/services/video_api_service.dart:17` |
| `POST` | `/api/videos` | `videos` | Bearer Token | Permission: videos:write | Required (X-Tenant-ID) | `multipart/form-data` | `object` <br>*(untyped dict)* | 201, 400, 401, 403, 422 | `lib/services/video_api_service.dart:48` |
| `DELETE` | `/api/videos/{video_id}` | `videos` | Bearer Token | TEACHER | Required (X-Tenant-ID) | `(None)`<br>Params: video_id (path, string, req) | `(None)` <br>*(untyped dict)* | 204, 400, 401, 403, 422 | `lib/services/video_api_service.dart:60` |
| `GET` | `/api/videos/{video_id}` | `videos` | Bearer Token | Permission: videos:read | Required (X-Tenant-ID) | `(None)`<br>Params: video_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/api/videos/{video_id}/stream` | `videos` | Bearer Token | Permission: videos:read | Required (X-Tenant-ID) | `(None)`<br>Params: video_id (path, string, req) | `(None)` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/docs` | `fastapi.applications` | Public | Public (Unauthenticated) | None | `(None)` | `(None)` <br>*(untyped dict)* |  | *Backend/Direct* |
| `GET` | `/docs/oauth2-redirect` | `fastapi.applications` | Bearer Token | Authenticated | Required (X-Tenant-ID) | `(None)` | `(None)` <br>*(untyped dict)* | 400, 401, 403 | *Backend/Direct* |
| `GET` | `/health/live` | `app.main` | Public | Public (Unauthenticated) | None | `(None)` | `object` <br>*(untyped dict)* | 200 | *Backend/Direct* |
| `GET` | `/health/ready` | `app.main` | Public | Public (Unauthenticated) | None | `(None)` | `object` <br>*(untyped dict)* | 200 | *Backend/Direct* |
| `GET` | `/openapi.json` | `fastapi.applications` | Public | Public (Unauthenticated) | None | `(None)` | `(None)` <br>*(untyped dict)* |  | *Backend/Direct* |
| `POST` | `/platform/auth/login` | `auth` | Public | Public | Platform Scope (No X-Tenant-ID) | `LoginInput` | `object` <br>*(untyped dict)* | 200, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/platform/schools` | `platform` | Bearer Token | SUPER_ADMIN | Platform Scope (No X-Tenant-ID) | `(None)` | `List[object]` | 200, 401, 403 | *Backend/Direct* |
| `POST` | `/platform/schools` | `platform` | Bearer Token | SUPER_ADMIN | Platform Scope (No X-Tenant-ID) | `SchoolInput` | `object` <br>*(untyped dict)* | 201, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/platform/schools/{tenant_id}` | `platform` | Bearer Token | SUPER_ADMIN | Platform Scope (No X-Tenant-ID) | `(None)`<br>Params: tenant_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `PUT` | `/platform/schools/{tenant_id}/status` | `platform` | Bearer Token | SUPER_ADMIN | Platform Scope (No X-Tenant-ID) | `object`<br>Params: tenant_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/platform/schools/{tenant_id}/validate` | `platform` | Public | Public | Platform Scope (No X-Tenant-ID) | `(None)`<br>Params: tenant_id (path, string, req) | `object` <br>*(untyped dict)* | 200, 400, 422 | *Backend/Direct* |
| `POST` | `/platform/users` | `platform` | Bearer Token | SUPER_ADMIN | Platform Scope (No X-Tenant-ID) | `PlatformUserInput` | `object` <br>*(untyped dict)* | 201, 401, 403, 422 | *Backend/Direct* |
| `GET` | `/redoc` | `fastapi.applications` | Public | Public (Unauthenticated) | None | `(None)` | `(None)` <br>*(untyped dict)* |  | *Backend/Direct* |

## Unresolved Payload Contracts Inventory

The following endpoints return untyped Python dictionaries without explicit Pydantic response models in the existing FastAPI backend. Exact wire shapes must be codified with Pydantic schemas during Phase 2/4 migration:

| Method | Path | Function | Handler Module | Current Response Description |
| --- | --- | --- | --- | --- |
| `POST` | `/api/academic-years/rollover` | `roll_over_class` | `rollover` | `object` |
| `GET` | `/api/academic-years/rollover/{run_id}` | `get_rollover` | `rollover` | `object` |
| `GET` | `/api/ai-config` | `get_config` | `ai` | `object` |
| `PUT` | `/api/ai-config` | `put_config` | `ai` | `object` |
| `POST` | `/api/ai/chat` | `chat` | `ai` | `object` |
| `GET` | `/api/ai/conversations/{conversation_id}` | `conversation` | `ai` | `object` |
| `GET` | `/api/attendance/student/{student_id}/summary` | `student_summary` | `attendance` | `object` |
| `DELETE` | `/api/attendance/{record_id}` | `void_attendance` | `attendance` | `(None)` |
| `POST` | `/api/auth/login` | `login_school` | `auth` | `object` |
| `POST` | `/api/auth/logout` | `logout` | `auth` | `object` |
| `POST` | `/api/auth/refresh` | `refresh` | `auth` | `object` |
| `POST` | `/api/certificates/generate` | `generate_certificate` | `school_workflows` | `object` |
| `POST` | `/api/chat/rooms` | `get_or_create_room` | `chat` | `object` |
| `POST` | `/api/chat/rooms/{room_id}/messages` | `send_message` | `chat` | `object` |
| `PUT` | `/api/chat/rooms/{room_id}/read` | `mark_read` | `chat` | `(None)` |
| `POST` | `/api/contact/enquiry` | `submit_contact` | `public` | `object` |
| `POST` | `/api/discipline` | `create_incident` | `school_workflows` | `object` |
| `GET` | `/api/discipline/summary` | `incident_summary` | `school_workflows` | `object` |
| `PUT` | `/api/discipline/{incident_id}/resolve` | `resolve_incident` | `school_workflows` | `object` |
| `POST` | `/api/expenses` | `add_expense` | `expenses` | `object` |
| `DELETE` | `/api/expenses/{expense_id}` | `void_expense` | `expenses` | `(None)` |
| `POST` | `/api/fees/collect` | `collect_fee` | `payments` | `object` |
| `GET` | `/api/fees/payments` | `list_payments` | `payments` | `object` |
| `GET` | `/api/fees/payments/{payment_id}` | `get_payment` | `payments` | `object` |
| `POST` | `/api/fees/payments/{payment_id}/void` | `void_payment` | `payments` | `object` |
| `DELETE` | `/api/feestructures/{structure_id}` | `delete_structure` | `fees` | `(None)` |
| `POST` | `/api/homework` | `create_homework` | `school_workflows` | `object` |
| `DELETE` | `/api/homework/{homework_id}` | `delete_homework` | `school_workflows` | `(None)` |
| `GET` | `/api/homework/{homework_id}` | `get_homework` | `school_workflows` | `object` |
| `PUT` | `/api/homework/{homework_id}` | `update_homework` | `school_workflows` | `object` |
| `POST` | `/api/leave/apply` | `apply_leave` | `hr` | `object` |
| `DELETE` | `/api/leave/{leave_id}` | `cancel_leave` | `hr` | `(None)` |
| `PUT` | `/api/leave/{leave_id}/approve` | `decide_leave` | `hr` | `object` |
| `GET` | `/api/master-data` | `master_data` | `master_data` | `object` |
| `GET` | `/api/master-data/class-subjects` | `get_class_subjects` | `master_data` | `object` |
| `PUT` | `/api/master-data/class-subjects` | `save_class_subjects` | `master_data` | `object` |
| `PUT` | `/api/master-data/subjects` | `add_subject` | `master_data` | `object` |
| `POST` | `/api/notifications` | `create_notification` | `notifications` | `object` |
| `DELETE` | `/api/notifications/{notice_id}` | `delete_notification` | `notifications` | `(None)` |
| `PUT` | `/api/notifications/{notice_id}` | `update_notification` | `notifications` | `object` |
| `PUT` | `/api/notifications/{notice_id}/read` | `mark_read` | `notifications` | `object` |
| `GET` | `/api/parent/child/{student_id}/attendance/summary` | `child_attendance_summary` | `portals` | `object` |
| `GET` | `/api/parent/child/{student_id}/fees` | `child_fees` | `portals` | `object` |
| `GET` | `/api/parent/child/{student_id}/results` | `child_results` | `portals` | `object` |
| `GET` | `/api/parent/dashboard` | `parent_dashboard` | `portals` | `object` |
| `GET` | `/api/reports/fees/report-summary` | `fee_report` | `reports` | `object` |
| `GET` | `/api/reports/school-summary` | `school_summary` | `reports` | `object` |
| `GET` | `/api/results/class/{class_name}/analytics` | `get_class_analytics` | `results` | `object` |
| `POST` | `/api/results/coscholastic` | `save_coscholastic` | `results` | `object` |
| `POST` | `/api/results/exam-config` | `save_exam_config` | `results` | `object` |
| `GET` | `/api/results/grading-policy` | `get_grading_policy` | `results` | `object` |
| `PUT` | `/api/results/grading-policy` | `save_grading_policy` | `results` | `object` |
| `PUT` | `/api/results/publish` | `publish_results` | `results` | `object` |
| `GET` | `/api/results/student/{student_id}/report` | `get_report_card` | `results` | `object` |
| `DELETE` | `/api/results/{result_id}` | `void_result` | `results` | `(None)` |
| `PUT` | `/api/results/{result_id}` | `update_result` | `results` | `object` |
| `PUT` | `/api/salary/{salary_id}/pay` | `pay_salary` | `hr` | `object` |
| `GET` | `/api/school/profile` | `get_profile` | `school_profile` | `object` |
| `PUT` | `/api/school/profile` | `update_profile` | `school_profile` | `object` |
| `GET` | `/api/site-content` | `get_site_content` | `site_content` | `object` |
| `PUT` | `/api/site-content` | `save_site_content` | `site_content` | `object` |
| `POST` | `/api/staff` | `create_staff` | `hr` | `object` |
| `GET` | `/api/staff/dashboard` | `dashboard` | `hr` | `object` |
| `DELETE` | `/api/staff/{staff_id}` | `delete_staff` | `hr` | `(None)` |
| `GET` | `/api/staff/{staff_id}` | `get_staff` | `hr` | `object` |
| `PUT` | `/api/staff/{staff_id}` | `update_staff` | `hr` | `object` |
| `GET` | `/api/student-fee-profiles/{student_id}` | `get_profile` | `fees` | `object` |
| `GET` | `/api/student-portal/attendance/summary` | `student_attendance_summary` | `portals` | `object` |
| `GET` | `/api/student-portal/dashboard` | `student_dashboard` | `portals` | `object` |
| `GET` | `/api/student-portal/fees` | `student_fees` | `portals` | `object` |
| `GET` | `/api/student-portal/results` | `student_results` | `portals` | `object` |
| `POST` | `/api/students/add` | `admit_student` | `students` | `object` |
| `POST` | `/api/students/enquiry` | `create_enquiry` | `students` | `object` |
| `DELETE` | `/api/students/{student_id}` | `delete_enquiry` | `students` | `(None)` |
| `GET` | `/api/students/{student_id}` | `get_student` | `students` | `object` |
| `PUT` | `/api/students/{student_id}` | `save_student` | `students` | `object` |
| `POST` | `/api/timetable` | `save_day` | `timetable` | `object` |
| `DELETE` | `/api/timetable/entry/{day_id}` | `delete_day` | `timetable` | `(None)` |
| `DELETE` | `/api/timetable/{class_name}` | `delete_class` | `timetable` | `(None)` |
| `POST` | `/api/transport/assignments` | `assign_student` | `transport` | `object` |
| `GET` | `/api/transport/assignments/student/{student_id}` | `student_assignment` | `transport` | `(None)` |
| `DELETE` | `/api/transport/assignments/{assignment_id}` | `remove_assignment` | `transport` | `(None)` |
| `POST` | `/api/transport/buses` | `create_bus` | `transport` | `object` |
| `DELETE` | `/api/transport/buses/{bus_id}` | `delete_bus` | `transport` | `(None)` |
| `PUT` | `/api/transport/buses/{bus_id}` | `update_bus` | `transport` | `object` |
| `POST` | `/api/transport/routes` | `create_route` | `transport` | `object` |
| `DELETE` | `/api/transport/routes/{route_id}` | `delete_route` | `transport` | `(None)` |
| `PUT` | `/api/transport/routes/{route_id}` | `update_route` | `transport` | `object` |
| `GET` | `/api/transport/stats` | `stats` | `transport` | `object` |
| `POST` | `/api/users` | `create_user` | `users` | `object` |
| `POST` | `/api/users/change-password` | `change_password` | `users` | `object` |
| `DELETE` | `/api/users/{user_id}` | `deactivate_user` | `users` | `(None)` |
| `GET` | `/api/users/{user_id}` | `get_user` | `users` | `object` |
| `PUT` | `/api/users/{user_id}` | `update_user` | `users` | `object` |
| `POST` | `/api/videos` | `upload_video` | `videos` | `object` |
| `DELETE` | `/api/videos/{video_id}` | `delete_video` | `videos` | `(None)` |
| `GET` | `/api/videos/{video_id}` | `get_video` | `videos` | `object` |
| `GET` | `/api/videos/{video_id}/stream` | `stream_video` | `videos` | `(None)` |
| `GET` | `/docs` | `swagger_ui_html` | `fastapi.applications` | `(None)` |
| `GET` | `/docs/oauth2-redirect` | `swagger_ui_redirect` | `fastapi.applications` | `(None)` |
| `GET` | `/health/live` | `live` | `app.main` | `object` |
| `GET` | `/health/ready` | `ready` | `app.main` | `object` |
| `GET` | `/openapi.json` | `openapi` | `fastapi.applications` | `(None)` |
| `POST` | `/platform/auth/login` | `login_platform` | `auth` | `object` |
| `POST` | `/platform/schools` | `create_school` | `platform` | `object` |
| `GET` | `/platform/schools/{tenant_id}` | `get_school` | `platform` | `object` |
| `PUT` | `/platform/schools/{tenant_id}/status` | `school_status` | `platform` | `object` |
| `GET` | `/platform/schools/{tenant_id}/validate` | `validate_school` | `platform` | `object` |
| `POST` | `/platform/users` | `create_platform_user` | `platform` | `object` |
| `GET` | `/redoc` | `redoc_html` | `fastapi.applications` | `(None)` |
