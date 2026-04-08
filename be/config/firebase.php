<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Firebase Cloud Messaging (FCM) Configuration
    |--------------------------------------------------------------------------
    |
    | Konfigurasi untuk Firebase Cloud Messaging yang digunakan untuk
    | mengirim push notifications ke mobile devices.
    |
    */

    'fcm' => [
        'api_key' => env('FIREBASE_API_KEY'),
        'project_id' => env('FIREBASE_PROJECT_ID'),
        'sender_id' => env('FIREBASE_SENDER_ID'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Notification Settings
    |--------------------------------------------------------------------------
    |
    | Konfigurasi untuk perilaku notifikasi sistem
    |
    */

    'notification' => [
        // Berapa hari sebelum di-escalate ke email
        'email_after_days' => env('NOTIFICATION_EMAIL_AFTER_DAYS', 3),

        // Jam berapa jalankan cron job untuk send email (format 24 jam)
        'check_schedule' => env('NOTIFICATION_CHECK_SCHEDULE', '09:00'),
    ],
];
