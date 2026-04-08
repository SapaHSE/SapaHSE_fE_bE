<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class NotificationService
{
    /**
     * Send push notification via Firebase Cloud Messaging
     */
    public function sendPushNotification(User $user, string $title, string $body, array $data = []): bool
    {
        if (!$user->fcm_token) {
            Log::warning('User tidak memiliki FCM token', ['user_id' => $user->id]);
            return false;
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . config('firebase.fcm.api_key'),
                'Content-Type' => 'application/json',
            ])->post('https://fcm.googleapis.com/fcm/send', [
                'to' => $user->fcm_token,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                    'sound' => 'default',
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                ],
                'data' => $data,
                'priority' => 'high',
            ]);

            if ($response->successful()) {
                Log::info('Push notification terkirim', [
                    'user_id' => $user->id,
                    'fcm_token' => substr($user->fcm_token, 0, 20) . '...',
                ]);
                return true;
            } else {
                Log::error('Gagal mengirim push notification', [
                    'user_id' => $user->id,
                    'response' => $response->body(),
                ]);
                return false;
            }
        } catch (\Exception $e) {
            Log::error('Error saat mengirim push notification', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Create dan send notification
     */
    public function createNotification(
        User $user,
        string $type,
        string $title,
        string $body,
        array $data = []
    ): Notification {
        $notification = Notification::create([
            'user_id' => $user->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'status' => 'pending',
        ]);

        // Coba kirim push notification
        if ($this->sendPushNotification($user, $title, $body, $data)) {
            $notification->update([
                'status' => 'sent_push',
                'pushed_at' => now(),
            ]);
        }

        return $notification;
    }

    /**
     * Send email untuk notification yang belum dibaca setelah 3 hari
     */
    public function sendEmailForUnreadNotification(Notification $notification): bool
    {
        if (!$notification->user->email) {
            Log::warning('User tidak punya email', ['user_id' => $notification->user_id]);
            return false;
        }

        try {
            Mail::send('emails.notification-reminder', [
                'user' => $notification->user,
                'notification' => $notification,
            ], function ($message) use ($notification) {
                $message->to($notification->user->email)
                    ->subject('Pengingat: ' . $notification->title);
            });

            $notification->update([
                'status' => 'sent_email',
                'emailed_at' => now(),
            ]);

            Log::info('Email notification terkirim', [
                'notification_id' => $notification->id,
                'user_email' => $notification->user->email,
            ]);

            return true;
        } catch (\Exception $e) {
            Log::error('Error saat mengirim email notification', [
                'notification_id' => $notification->id,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Check dan send email untuk notifikasi yang belum dibaca > 3 hari
     */
    public function checkAndSendEmailForExpiredNotifications(): int
    {
        $days = config('firebase.notification.email_after_days', 3);

        $unreadNotifications = Notification::where('status', 'sent_push')
            ->where('read_at', null)
            ->where('pushed_at', '<=', now()->subDays($days))
            ->get();

        $sent = 0;
        foreach ($unreadNotifications as $notification) {
            if ($this->sendEmailForUnreadNotification($notification)) {
                $sent++;
            }
        }

        Log::info('Email notification check selesai', [
            'total_checked' => count($unreadNotifications),
            'total_sent' => $sent,
        ]);

        return $sent;
    }

    /**
     * Update last activity user
     */
    public function updateLastActivity(User $user): void
    {
        $user->update([
            'last_activity_at' => now(),
        ]);
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Notification $notification): void
    {
        $notification->update([
            'status' => 'read',
            'read_at' => now(),
        ]);
    }
}
