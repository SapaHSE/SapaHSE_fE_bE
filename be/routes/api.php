<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\ProfileController;
use App\Http\Controllers\API\HazardReportController;
use App\Http\Controllers\API\InspectionReportController;
use App\Http\Controllers\API\DashboardController;
use App\Http\Controllers\API\StatisticsController;
use App\Http\Controllers\API\NewsController;
use App\Http\Controllers\API\AnnouncementController;
use App\Http\Controllers\API\QrAssetController;
use App\Http\Controllers\API\InboxController;
use App\Http\Controllers\API\ForgotPasswordController;
use App\Http\Controllers\API\NotificationController;
use App\Http\Controllers\API\HazardCategoryController;
use App\Http\Controllers\API\ViolationController;
use App\Http\Controllers\API\CompanyController;
use App\Http\Controllers\API\AreaController;
use App\Http\Controllers\API\DepartmentController;

// ── Public Routes ─────────────────────────────────────────────────────────────

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login',    [AuthController::class, 'login']);

// Master Data (Public for Registration & Dropdowns)
Route::get('/companies', [CompanyController::class, 'index']);
Route::get('/departments', [DepartmentController::class, 'index']);
Route::get('/areas',     [AreaController::class, 'index']);
Route::get('/pic-users', [AuthController::class, 'picUsers']);

// ── Email Verification ────────────────────────────────────────────────────────
Route::get('/email/verify/{id}/{token}', [AuthController::class, 'verifyEmail']);  // dibuka via browser
Route::post('/email/resend',             [AuthController::class, 'resendVerification']);

// ── Forgot Password ───────────────────────────────────────────────────────────
Route::post('/forgot-password', [ForgotPasswordController::class, 'sendResetOtp']);

// News & Announcements can be read without login
Route::get('/news',      [NewsController::class, 'index']);
Route::get('/news/{id}', [NewsController::class, 'show']);

// ── Protected Routes (all roles) ──────────────────────────────────────────────

Route::middleware('auth:sanctum')->group(function () {

    // ── Auth ─────────────────────────────────────────────────────────────────
    Route::post('/logout', [AuthController::class, 'logout']);

    // ── Profile ───────────────────────────────────────────────────────────────
    Route::get('/profile/statistics',       [StatisticsController::class, 'personalStatistics']);
    Route::get('/profile',                  [ProfileController::class, 'getProfile']);
    Route::post('/profile',                 [ProfileController::class, 'updateProfile']);
    Route::delete('/profile',               [ProfileController::class, 'destroyAccount']);
    Route::post('/profile/change-password', [ProfileController::class, 'changePassword']);
    Route::get('/profile/change-requests',  [ProfileController::class, 'getProfileChangeRequests']);
    Route::post('/profile/mine-permit/request', [ProfileController::class, 'requestMinePermit']);
    Route::post('/profile/license',         [ProfileController::class, 'storeLicense']);
    Route::put('/profile/license/{id}',      [ProfileController::class, 'updateLicense']);
    Route::delete('/profile/license/{id}',   [ProfileController::class, 'destroyLicense']);

    Route::post('/profile/certification',   [ProfileController::class, 'storeCertification']);
    Route::put('/profile/certification/{id}', [ProfileController::class, 'updateCertification']);
    Route::delete('/profile/certification/{id}', [ProfileController::class, 'destroyCertification']);

    Route::post('/profile/medical',         [ProfileController::class, 'storeMedical']);
    Route::put('/profile/medical/{id}',      [ProfileController::class, 'updateMedical']);
    Route::delete('/profile/medical/{id}',   [ProfileController::class, 'destroyMedical']);

    // View another user's full profile (read-only)
    Route::get('/users/{id}/profile', [ProfileController::class, 'getUserProfileById']);


    // ── Hazard Reports ────────────────────────────────────────────────────────
    Route::get('/hazard-reports',              [HazardReportController::class, 'index']);
    Route::post('/hazard-reports',             [HazardReportController::class, 'store']);
    Route::get('/hazard-reports/{id}',         [HazardReportController::class, 'show']);
    Route::get('/hazard-reports/{id}/logs',    [HazardReportController::class, 'logs']);
    Route::get('/hazard-reports/{id}/logs/{logId}/replies', [HazardReportController::class, 'logReplies']);
    Route::post('/hazard-reports/{id}/logs/{logId}/replies', [HazardReportController::class, 'createLogReply']);
    Route::delete('/hazard-reports/{id}',      [HazardReportController::class, 'destroy']);
    Route::post('/hazard-reports/{id}/status', [HazardReportController::class, 'updateStatus']);

    // ── Hazard Categories ─────────────────────────────────────────────────────
    Route::get('/hazard-categories', [HazardCategoryController::class, 'index']);
    Route::post('/hazard-categories', [HazardCategoryController::class, 'store'])
        ->middleware('permission:manage_master_data');
    Route::put('/hazard-categories/{id}', [HazardCategoryController::class, 'update'])
        ->middleware('permission:manage_master_data');
    Route::delete('/hazard-categories/{id}', [HazardCategoryController::class, 'destroy'])
        ->middleware('permission:manage_master_data');

    // Subcategories
    Route::post('/hazard-categories/subcategories/{subId}/toggle', [HazardCategoryController::class, 'toggleSubcategory'])
        ->middleware('permission:manage_master_data');

    Route::post('/hazard-categories/{categoryId}/subcategories', [HazardCategoryController::class, 'storeSubcategory'])
        ->middleware('permission:manage_master_data');
    Route::put('/hazard-categories/{categoryId}/subcategories/{subId}', [HazardCategoryController::class, 'updateSubcategory'])
        ->middleware('permission:manage_master_data');
    Route::delete('/hazard-categories/{categoryId}/subcategories/{subId}', [HazardCategoryController::class, 'destroySubcategory'])
        ->middleware('permission:manage_master_data');

    // ── Companies ─────────────────────────────────────────────────────────────
    // GET /companies is public (top of file) for registration dropdowns.
    Route::post('/companies', [CompanyController::class, 'store'])
        ->middleware('permission:manage_master_data');
    Route::put('/companies/{id}', [CompanyController::class, 'update'])
        ->middleware('permission:manage_master_data');
    Route::delete('/companies/{id}', [CompanyController::class, 'destroy'])
        ->middleware('permission:manage_master_data');
    Route::post('/companies/{id}/toggle', [CompanyController::class, 'toggle'])
        ->middleware('permission:manage_master_data');

    // ── Areas ─────────────────────────────────────────────────────────────────
    // GET /areas is public (top of file) for registration / reference.
    Route::post('/areas', [AreaController::class, 'store'])
        ->middleware('permission:manage_master_data');
    Route::put('/areas/{id}', [AreaController::class, 'update'])
        ->middleware('permission:manage_master_data');
    Route::delete('/areas/{id}', [AreaController::class, 'destroy'])
        ->middleware('permission:manage_master_data');
    Route::post('/areas/{id}/toggle', [AreaController::class, 'toggle'])
        ->middleware('permission:manage_master_data');


    // ── Inspection Reports ────────────────────────────────────────────────────
    Route::get('/inspection-reports',              [InspectionReportController::class, 'index']);
    Route::post('/inspection-reports',             [InspectionReportController::class, 'store']);
    Route::get('/inspection-reports/{id}',         [InspectionReportController::class, 'show']);
    Route::get('/inspection-reports/{id}/logs',    [InspectionReportController::class, 'logs']);
    Route::get('/inspection-reports/{id}/logs/{logId}/replies', [InspectionReportController::class, 'logReplies']);
    Route::post('/inspection-reports/{id}/logs/{logId}/replies', [InspectionReportController::class, 'createLogReply']);
    Route::delete('/inspection-reports/{id}',      [InspectionReportController::class, 'destroy']);
    Route::post('/inspection-reports/{id}/status', [InspectionReportController::class, 'updateStatus']);

    // GET /api/users  — daftar user untuk fitur Tag Orang
    Route::get('/users', [AuthController::class, 'listUsers']);
    
    // GET /api/departments  — daftar departemen unik (semua role yang login)
    // ── Departments Management ────────────────────────────────────────────────
    Route::post('/departments', [DepartmentController::class, 'store'])
        ->middleware('permission:manage_master_data');
    Route::put('/departments/{id}', [DepartmentController::class, 'update'])
        ->middleware('permission:manage_master_data');
    Route::delete('/departments/{id}', [DepartmentController::class, 'destroy'])
        ->middleware('permission:manage_master_data');
        
    // Inspections merged into /api/reports    // ==========================================
    // News & Articles
    // ==========================================
    Route::get('/news',                  [NewsController::class, 'index']);
    Route::get('/news/{id}',             [NewsController::class, 'show']);
    Route::post('/news',                 [NewsController::class, 'store'])->middleware('permission:manage_news');
    Route::delete('/news/{id}',          [NewsController::class, 'destroy'])->middleware('permission:manage_news');

    // ==========================================
    // Inbox / Announcements (Inbox) ─────────────────────────────────────────────────
    // GET    /api/announcements          → list + unread_count
    // GET    /api/announcements/{id}     → detail + auto mark as read
    // POST   /api/announcements          → create (admin/supervisor only)
    // DELETE /api/announcements/{id}     → deactivate (admin only)
    // PATCH  /api/announcements/read-all → mark all as read
    Route::get('/announcements',              [AnnouncementController::class, 'index']);
    Route::get('/announcements/{id}',         [AnnouncementController::class, 'show']);
    Route::patch('/announcements/read-all',   [AnnouncementController::class, 'markAllAsRead']);
    Route::post('/announcements',             [AnnouncementController::class, 'store'])
        ->middleware('permission:manage_announcements');
    Route::delete('/announcements/{id}',      [AnnouncementController::class, 'destroy'])
        ->middleware('permission:manage_announcements');
            // Inbox — gabungan reports + announcements
    Route::get('/inbox',           [InboxController::class, 'index']);
    Route::post('/inbox/read',     [InboxController::class, 'markAsRead']);
    Route::post('/inbox/read-all', [InboxController::class, 'markAllAsRead']);

    // ── News (admin/supervisor manage) ────────────────────────────────────────
    Route::post('/news',        [NewsController::class, 'store'])
        ->middleware('permission:manage_news');
    Route::post('/news/{id}/publish-now', [NewsController::class, 'publishNow'])
        ->middleware('permission:manage_news');
    Route::delete('/news/{id}', [NewsController::class, 'destroy'])
        ->middleware('permission:manage_news');

    // ── Dashboard Statistics ──────────────────────────────────────────────────
    Route::get('/dashboard/statistics', [DashboardController::class, 'statistics'])
        ->middleware('permission:dashboard_overview');

    // GET /api/users  — daftar user untuk fitur Tag Orang
    Route::get('/users', [AuthController::class, 'listUsers']);

    // ── QR Assets ─────────────────────────────────────────────────────────────
    // GET /api/qr-assets              → list all assets
    // GET /api/qr-assets/scan         → scan by qr_code (?qr_code=BBE-APAR-...)
    Route::get('/qr-assets',       [QrAssetController::class, 'index']);
    Route::get('/qr-assets/scan',  [QrAssetController::class, 'scan']);
    Route::get('/qr/me',           [QrAssetController::class, 'myQr']);
    Route::get('/qr/scan',         [QrAssetController::class, 'scanAny']);

    // ── Notifications ─────────────────────────────────────────────────────────
    // POST   /api/notifications/register-fcm    → register FCM token dari mobile
    // GET    /api/notifications                 → list notifications
    // GET    /api/notifications/{id}            → get single notification
    // POST   /api/notifications/{id}/read       → mark as read
    // POST   /api/notifications/activity        → update last activity
    // GET    /api/notifications/unread/count    → get unread count
    Route::post('/notifications/register-fcm',       [NotificationController::class, 'registerFcmToken']);
    Route::post('/notifications/unregister-fcm',     [NotificationController::class, 'unregisterFcmToken']);
    Route::get('/notifications',                     [NotificationController::class, 'getNotifications']);
    Route::get('/notifications/unread/count',        [NotificationController::class, 'getUnreadCount']);
    Route::post('/notifications/read-all',           [NotificationController::class, 'markAllAsRead']);
    Route::get('/notifications/{notification}',      [NotificationController::class, 'getNotification']);
    Route::post('/notifications/{notification}/read',[NotificationController::class, 'markAsRead']);
    Route::post('/notifications/activity',           [NotificationController::class, 'registerFcmToken']); // legacy alias

    Route::get('/me', [AuthController::class, 'me']);

    // ── Users (admin/superadmin only) ────────────────────────────────────────
    Route::get('/admin/registration-approvals', [AuthController::class, 'registrationApprovalsIndex']);
    Route::put('/admin/registration-approvals/{id}/approve', [AuthController::class, 'adminApprove']);
    Route::post('/admin/registration-approvals/{id}/reject', [AuthController::class, 'adminReject']);
    Route::get('/admin/users', [AuthController::class, 'adminIndex'])->middleware('permission:manage_users');
    Route::post('/admin/users', [AuthController::class, 'adminStore'])->middleware('permission:manage_users');
    Route::put('/admin/users/{id}', [AuthController::class, 'adminUpdate'])->middleware('permission:manage_users');
    Route::put('/admin/users/{id}/approve', [AuthController::class, 'adminApprove'])->middleware('permission:manage_users');
    Route::post('/admin/users/{id}/reject', [AuthController::class, 'adminReject'])->middleware('permission:manage_users');
    Route::get('/admin/registration-logs', [AuthController::class, 'adminRejectedLogs'])->middleware('permission:manage_users');    
    Route::delete('/admin/users/{id}', [AuthController::class, 'adminDestroy'])->middleware('permission:manage_users');

    // Admin: Manage Violations
    Route::get('/admin/violations', [ViolationController::class, 'index'])->middleware('permission:manage_violations');
    Route::post('/admin/users/{id}/violations', [ViolationController::class, 'store'])->middleware('permission:manage_violations');
    Route::get('/admin/violations/{violationId}', [ViolationController::class, 'show'])->middleware('permission:manage_violations');
    Route::put('/admin/violations/{violationId}', [ViolationController::class, 'update'])->middleware('permission:manage_violations');
    Route::delete('/admin/violations/{violationId}', [ViolationController::class, 'destroy'])->middleware('permission:manage_violations');

    // Admin: Verification
    Route::get('/admin/document-approvals', [InboxController::class, 'documentApprovals'])->middleware('permission:document_approvals');
    Route::put('/admin/licenses/{id}/verify', [AuthController::class, 'adminVerifyLicense'])->middleware('permission:document_approvals');
    Route::put('/admin/certifications/{id}/verify', [AuthController::class, 'adminVerifyCertification'])->middleware('permission:document_approvals');
    Route::put('/admin/licenses/{id}/approve', [AuthController::class, 'adminApproveLicense'])->middleware('permission:document_approvals');
    Route::post('/admin/licenses/{id}/reject', [AuthController::class, 'adminRejectLicense'])->middleware('permission:document_approvals');
    Route::put('/admin/certifications/{id}/approve', [AuthController::class, 'adminApproveCertification'])->middleware('permission:document_approvals');
    Route::post('/admin/certifications/{id}/reject', [AuthController::class, 'adminRejectCertification'])->middleware('permission:document_approvals');

    // Admin: Profile Change Requests
    Route::put('/admin/profile-change-requests/{id}/approve', [ProfileController::class, 'adminApproveProfileChange'])->middleware('permission:document_approvals');
    Route::post('/admin/profile-change-requests/{id}/reject', [ProfileController::class, 'adminRejectProfileChange'])->middleware('permission:document_approvals');

});
