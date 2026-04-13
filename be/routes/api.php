<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\ProfileController;
use App\Http\Controllers\API\ReportController;
use App\Http\Controllers\API\NewsController;
use App\Http\Controllers\API\AnnouncementController;
use App\Http\Controllers\API\QrAssetController;
use App\Http\Controllers\API\InboxController;
use App\Http\Controllers\API\ForgotPasswordController;
use App\Http\Controllers\API\NotificationController;

// ── Public Routes ─────────────────────────────────────────────────────────────

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login',    [AuthController::class, 'login']);

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
    Route::get('/profile',                  [ProfileController::class, 'getProfile']);
    Route::post('/profile',                 [ProfileController::class, 'updateProfile']);
    Route::delete('/profile',               [ProfileController::class, 'destroyAccount']);
    Route::post('/profile/change-password', [ProfileController::class, 'changePassword']);
    Route::post('/profile/license',         [ProfileController::class, 'storeLicense']);
    Route::put('/profile/license/{id}',      [ProfileController::class, 'updateLicense']);
    Route::delete('/profile/license/{id}',   [ProfileController::class, 'destroyLicense']);

    Route::post('/profile/certification',   [ProfileController::class, 'storeCertification']);
    Route::put('/profile/certification/{id}', [ProfileController::class, 'updateCertification']);
    Route::delete('/profile/certification/{id}', [ProfileController::class, 'destroyCertification']);

    Route::post('/profile/medical',         [ProfileController::class, 'storeMedical']);
    Route::put('/profile/medical/{id}',      [ProfileController::class, 'updateMedical']);
    Route::delete('/profile/medical/{id}',   [ProfileController::class, 'destroyMedical']);

    // ── Reports (Hazard) ──────────────────────────────────────────────────────
    // GET    /api/reports              → list all reports (filter, search, paginate)
    // POST   /api/reports              → create new report
    // GET    /api/reports/{id}         → detail + auto mark as read
    // DELETE /api/reports/{id}         → delete own report (admin can delete all)
    // PATCH  /api/reports/{id}/status  → update status (admin/supervisor only)
    Route::get('/reports',               [ReportController::class, 'index']);
    Route::get('/reports/statistics',    [ReportController::class, 'statistics']);
    Route::post('/reports',              [ReportController::class, 'store']);
    Route::get('/reports/{id}',          [ReportController::class, 'show']);
    Route::get('/reports/{id}/logs',     [ReportController::class, 'logs']);
    Route::delete('/reports/{id}',       [ReportController::class, 'destroy']);
    Route::post('/reports/{id}/status', [ReportController::class, 'updateStatus'])
        ->middleware('role:admin,superadmin');

    // Inspections merged into /api/reports    // ==========================================
    // News & Articles
    // ==========================================
    Route::get('/news',                  [NewsController::class, 'index']);
    Route::get('/news/{id}',             [NewsController::class, 'show']);
    Route::post('/news',                 [NewsController::class, 'store']);
    Route::delete('/news/{id}',          [NewsController::class, 'destroy']);

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
        ->middleware('role:admin,supervisor');
    Route::delete('/announcements/{id}',      [AnnouncementController::class, 'destroy'])
        ->middleware('role:admin');
            // Inbox — gabungan reports + announcements
    Route::get('/inbox',           [InboxController::class, 'index']);
    Route::post('/inbox/read',     [InboxController::class, 'markAsRead']);
    Route::post('/inbox/read-all', [InboxController::class, 'markAllAsRead']);

    // ── News (admin/supervisor manage) ────────────────────────────────────────
    Route::post('/news',        [NewsController::class, 'store'])
        ->middleware('role:admin,supervisor');
    Route::delete('/news/{id}', [NewsController::class, 'destroy'])
        ->middleware('role:admin');

    // ── QR Assets ─────────────────────────────────────────────────────────────
    // GET /api/qr-assets              → list all assets
    // GET /api/qr-assets/scan         → scan by qr_code (?qr_code=BBE-APAR-...)
    Route::get('/qr-assets',       [QrAssetController::class, 'index']);
    Route::get('/qr-assets/scan',  [QrAssetController::class, 'scan']);

    // ── Notifications ─────────────────────────────────────────────────────────
    // POST   /api/notifications/register-fcm    → register FCM token dari mobile
    // GET    /api/notifications                 → list notifications
    // GET    /api/notifications/{id}            → get single notification
    // POST   /api/notifications/{id}/read       → mark as read
    // POST   /api/notifications/activity        → update last activity
    // GET    /api/notifications/unread/count    → get unread count
    Route::post('/notifications/register-fcm',       [NotificationController::class, 'registerFcmToken']);
    Route::get('/notifications',                     [NotificationController::class, 'getNotifications']);
    Route::get('/notifications/unread/count',        [NotificationController::class, 'getUnreadCount']);
    Route::post('/notifications/read-all',           [NotificationController::class, 'markAllAsRead']);
    Route::get('/notifications/{notification}',      [NotificationController::class, 'getNotification']);
    Route::post('/notifications/{notification}/read',[NotificationController::class, 'markAsRead']);
    Route::post('/notifications/activity',           [NotificationController::class, 'registerFcmToken']); // legacy alias

    Route::get('/me', [AuthController::class, 'me']);
});