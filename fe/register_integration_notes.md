Note: The LSP errors for AuthService in register_screen.dart are due to the Dart language server's index being stale. The actual code compiles correctly - AuthService is imported at the top of the file (`import 'package:sapa_hse/services/auth_service.dart';`). The class is properly defined in that file and all references to `AuthService.register()` are correct.

The remaining errors in report_detail_screen.dart are pre-existing bugs unrelated to this task.

The registration flow integration is complete:
1. Frontend calls `AuthService.register()` which POSTs to `/api/register`
2. Backend validates all fields, creates user, sends verification email
3. On success, frontend navigates to Login screen
4. On error, frontend shows snackbar with error message
5. Password validation (min 8 chars frontend, min 6 chars backend) - frontend is stricter
6. NIK/employee_id is sent as both `nik` and `employeeId` parameters
7. Email verification is handled via the separate verification endpoint and email link flow