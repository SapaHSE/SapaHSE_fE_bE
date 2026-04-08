# Notification System Documentation

Dokumentasi lengkap untuk sistem notifikasi push notification dan email fallback di aplikasi Hazard.

## Overview

Sistem notifikasi terdiri dari:
1. **Push Notification** - Notifikasi real-time via Firebase Cloud Messaging (FCM)
2. **Email Fallback** - Email dikirim jika notifikasi tidak dibaca dalam 3 hari
3. **Activity Tracking** - Tracking kapan user terakhir active di aplikasi

## Architecture

```
┌─────────────────────┐
│   Mobile App        │
│   - Register FCM    │
│   - Send Activity   │
│   - Read Notif      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Backend (Laravel)                 │
│ ┌───────────────────────────────┐   │
│ │ NotificationService           │   │
│ │ - Create & Send Push Notif    │   │
│ │ - Track Activity              │   │
│ │ - Check & Send Email (3 days) │   │
│ └───────────────────────────────┘   │
└──────────┬────────────────────┬──────┘
           │                    │
    ┌──────▼────────┐    ┌─────▼────────┐
    │ Firebase FCM   │    │ Gmail SMTP   │
    │ (Push Notif)   │    │ (Email)      │
    └────────────────┘    └──────────────┘
```

## Setup Steps

### 1. Run Migrations

```bash
php artisan migrate
```

Ini akan membuat:
- Kolom baru di table `users` (fcm_token, last_activity_at, last_notification_sent_at)
- Table baru `notifications`

### 2. Configure Firebase

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Buat project baru atau gunakan yang sudah ada
3. Masuk ke **Project Settings** > **Service Accounts**
4. Ambil:
   - **API Key** → `FIREBASE_API_KEY`
   - **Project ID** → `FIREBASE_PROJECT_ID`
   - **Sender ID** → `FIREBASE_SENDER_ID` (dari Cloud Messaging tab)

5. Update `.env`:

```env
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_SENDER_ID=your_sender_id
```

### 3. Configure Email (Gmail)

1. Setup Gmail App Password:
   - Buka [Google Account Security](https://myaccount.google.com/security)
   - Enable 2-Factor Authentication
   - Generate App Password di: https://myaccount.google.com/apppasswords
   - Pilih "Mail" dan "Other (custom name)" → "Laravel App"

2. Update `.env`:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=your_email@gmail.com
MAIL_FROM_NAME="Hazard App"
```

### 4. Configure Notification Settings

Update `.env`:

```env
# Berapa hari sebelum di-escalate ke email (default: 3)
NOTIFICATION_EMAIL_AFTER_DAYS=3

# Jam berapa jalankan cron job untuk send email (default: 09:00)
NOTIFICATION_CHECK_SCHEDULE=09:00
```

### 5. Setup Task Scheduler

Di server production, setup cron job untuk menjalankan Laravel scheduler:

```bash
# Tambah ke crontab (setiap menit)
* * * * * cd /path/to/hazard-app && php artisan schedule:run >> /dev/null 2>&1
```

Di local development, bisa test dengan:

```bash
# Jalankan scheduler satu kali (untuk testing)
php artisan schedule:run

# Atau jalankan command langsung
php artisan notification:check-expired
```

## API Endpoints

### Register FCM Token

**Endpoint:** `POST /api/notifications/register-fcm`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Body:**
```json
{
  "fcm_token": "fabric_token_from_mobile_app"
}
```

**Response:**
```json
{
  "message": "FCM token berhasil didaftarkan",
  "data": {
    "user_id": "user-ulid",
    "fcm_token": "fabric_token_..."
  }
}
```

### Get Notifications

**Endpoint:** `GET /api/notifications?page=1`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "message": "Notifikasi berhasil diambil",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": "notification-ulid",
        "user_id": "user-ulid",
        "type": "inspection",
        "title": "Inspeksi Baru",
        "body": "Anda memiliki inspeksi baru yang perlu diselesaikan",
        "status": "sent_push",
        "pushed_at": "2026-04-06T10:00:00Z",
        "read_at": null,
        "created_at": "2026-04-06T10:00:00Z"
      }
    ],
    "last_page": 5,
    "per_page": 20,
    "total": 100
  }
}
```

### Get Single Notification

**Endpoint:** `GET /api/notifications/{id}`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "message": "Notifikasi berhasil diambil",
  "data": {
    "id": "notification-ulid",
    "user_id": "user-ulid",
    "type": "inspection",
    "title": "Inspeksi Baru",
    "body": "Anda memiliki inspeksi baru yang perlu diselesaikan",
    "data": {
      "inspection_id": "inspection-ulid"
    },
    "status": "sent_push",
    "pushed_at": "2026-04-06T10:00:00Z",
    "read_at": null
  }
}
```

### Mark Notification as Read

**Endpoint:** `POST /api/notifications/{id}/read`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "message": "Notifikasi berhasil ditandai sebagai dibaca",
  "data": {
    "id": "notification-ulid",
    "status": "read",
    "read_at": "2026-04-06T10:35:00Z"
  }
}
```

### Update User Activity

**Endpoint:** `POST /api/notifications/activity`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "message": "Activity berhasil diupdate",
  "data": {
    "user_id": "user-ulid",
    "last_activity_at": "2026-04-06T10:35:00Z"
  }
}
```

### Get Unread Count

**Endpoint:** `GET /api/notifications/unread/count`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "message": "Unread count berhasil diambil",
  "data": {
    "unread_count": 5
  }
}
```

## Usage Examples

### Backend (Laravel) - Create Notification

```php
use App\Services\NotificationService;
use App\Models\User;

// Inject NotificationService
$notificationService = app(NotificationService::class);

// Get user
$user = User::find($user_id);

// Create & send notification
$notification = $notificationService->createNotification(
    user: $user,
    type: 'inspection',
    title: 'Inspeksi Baru',
    body: 'Anda memiliki inspeksi baru yang perlu diselesaikan',
    data: [
        'inspection_id' => $inspection->id,
        'url' => '/inspections/' . $inspection->id,
    ]
);

// $notification->status akan menjadi 'sent_push' jika berhasil
```

### Mobile App (Flutter/React Native) - Register FCM

```javascript
// Setelah user login, register FCM token
const response = await fetch('https://api.yourapp.com/api/notifications/register-fcm', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`,
  },
  body: JSON.stringify({
    fcm_token: fcmToken,  // dari Firebase initialization
  }),
});
```

### Mobile App - Update Activity

```javascript
// Update activity setiap kali user membuka aplikasi atau interact
const updateActivity = async () => {
  await fetch('https://api.yourapp.com/api/notifications/activity', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
    },
  });
};
```

### Mobile App - Mark as Read

```javascript
// Setelah user membaca notifikasi
const markAsRead = async (notificationId) => {
  await fetch(`https://api.yourapp.com/api/notifications/${notificationId}/read`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
    },
  });
};
```

## Flow Diagram

### Push Notification Flow

```
1. Backend event terjadi (inspection baru, announcement, dll)
   ↓
2. NotificationService::createNotification() dipanggil
   ↓
3. Cek FCM token user → Ada?
   ├─ YA → Kirim push via Firebase
   │        Status: 'sent_push', pushed_at: now()
   │
   └─ TIDAK → Status: 'pending'
   
4. Mobile app terima push notification
   ├─ User buka app → Mark as read
   └─ User TIDAK buka dalam 3 hari → Email dikirim
```

### Email Escalation Flow

```
Every day at 09:00 (configurable):

1. Laravel scheduler jalankan: notification:check-expired
   ↓
2. Query notifications dengan:
   - status = 'sent_push'
   - read_at = null
   - pushed_at <= 3 hari lalu
   ↓
3. Untuk setiap notification:
   ├─ User punya email?
   │  ├─ YA → Send email
   │  └─ TIDAK → Skip
   ↓
4. Update status: 'sent_email', emailed_at: now()
```

## Testing

### Test Manual (Local)

1. Register user baru atau gunakan existing user
2. Setup .env dengan Gmail credentials
3. Run migration: `php artisan migrate`
4. Register FCM token (bisa gunakan dummy token untuk testing)
5. Create notification via Laravel tinker:

```bash
php artisan tinker

>>> $user = User::first();
>>> app(NotificationService::class)->createNotification(
...   user: $user,
...   type: 'test',
...   title: 'Test Notification',
...   body: 'This is a test'
... );
```

6. Check di database bahwa notification tercreate dan status 'sent_push'
7. Test email fallback:

```bash
# Run scheduler satu kali
php artisan schedule:run

# Atau jalankan command langsung
php artisan notification:check-expired
```

8. Check database untuk notification yang punya status 'sent_email'

### Test API

```bash
# Register FCM
curl -X POST http://localhost:8000/api/notifications/register-fcm \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"fcm_token":"test_token"}'

# Get notifications
curl http://localhost:8000/api/notifications \
  -H "Authorization: Bearer {token}"

# Get unread count
curl http://localhost:8000/api/notifications/unread/count \
  -H "Authorization: Bearer {token}"

# Update activity
curl -X POST http://localhost:8000/api/notifications/activity \
  -H "Authorization: Bearer {token}"
```

## Troubleshooting

### Push Notification tidak terkirim

1. Cek FCM token user di database:
   ```bash
   php artisan tinker
   >>> User::find($user_id)->fcm_token
   ```

2. Cek Firebase credentials di `.env`:
   ```bash
   FIREBASE_API_KEY=xxx
   FIREBASE_PROJECT_ID=xxx
   ```

3. Check logs:
   ```bash
   tail -f storage/logs/laravel.log | grep -i notification
   ```

### Email tidak terkirim

1. Cek Gmail credentials di `.env`:
   ```bash
   MAIL_MAILER=smtp
   MAIL_HOST=smtp.gmail.com
   MAIL_PORT=587
   ```

2. Test email directly:
   ```bash
   php artisan tinker
   >>> Mail::raw('Test email', function($msg) { 
   ...   $msg->to('your_email@gmail.com')->subject('Test');
   ... });
   ```

3. Check logs:
   ```bash
   tail -f storage/logs/laravel.log | grep -i mail
   ```

### Scheduler tidak berjalan

1. Check cron job di server:
   ```bash
   crontab -l
   ```

2. Ensure cron line sudah ada:
   ```bash
   * * * * * cd /path/to/hazard-app && php artisan schedule:run >> /dev/null 2>&1
   ```

3. Test scheduler manually:
   ```bash
   php artisan schedule:run
   ```

4. Check logs:
   ```bash
   php artisan schedule:list
   tail -f storage/logs/laravel.log | grep schedule
   ```

## Next Steps

1. **Integrate dengan existing models** - Update ReportController, InspectionController, AnnouncementController untuk otomatis create notification saat new item
2. **Add notification preferences** - User bisa pilih tipe notifikasi apa saja yang ingin diterima
3. **Add notification categories** - Group notifikasi by type/category di mobile app
4. **Add rich notification** - Image, action buttons, custom sounds
5. **Analytics** - Track notification delivery rate, open rate, click rate

## References

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Laravel Mail](https://laravel.com/docs/11.x/mail)
- [Laravel Task Scheduling](https://laravel.com/docs/11.x/scheduling)
- [Laravel Notifications](https://laravel.com/docs/11.x/notifications)
