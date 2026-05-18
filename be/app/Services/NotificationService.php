<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Google\Auth\HttpHandler\HttpHandlerFactory;

class NotificationService
{
    /**
     * Parse service-account credentials from env JSON or file path.
     */
    private function getFirebaseCredentials(): ?array
    {
        try {
            $credentialsConfig = config('firebase.fcm.credentials');

            if (!$credentialsConfig) {
                Log::error('FIREBASE_CREDENTIALS not set in .env');
                return null;
            }

            $credentialsConfig = trim((string) $credentialsConfig);

            // If it's a JSON string (for Railway), decode it.
            $jsonKey = json_decode($credentialsConfig, true);

            // Support base64-encoded JSON credentials to avoid quoting issues in env vars.
            if (json_last_error() !== JSON_ERROR_NONE) {
                $decodedBase64 = base64_decode($credentialsConfig, true);
                if ($decodedBase64 !== false) {
                    $jsonKey = json_decode($decodedBase64, true);
                }
            }

            if (json_last_error() !== JSON_ERROR_NONE) {
                if (file_exists($credentialsConfig)) {
                    $jsonKey = json_decode(file_get_contents($credentialsConfig), true);
                } else {
                    Log::error('Firebase credentials is not valid JSON/base64 JSON and file path was not found', [
                        'value_length' => strlen($credentialsConfig),
                        'starts_with_brace' => str_starts_with($credentialsConfig, '{'),
                        'contains_private_key_marker' => str_contains($credentialsConfig, 'BEGIN PRIVATE KEY'),
                    ]);
                    return null;
                }
            }

            if (!is_array($jsonKey) || empty($jsonKey)) {
                Log::error('Firebase credentials JSON could not be parsed into an array');
                return null;
            }

            return $jsonKey;
        } catch (\Exception $e) {
            Log::error('Gagal membaca Firebase credentials: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Get Access Token for FCM HTTP v1 using Service Account
     */
    private function getAccessToken(?array $jsonKey = null): ?string
    {
        try {
            $jsonKey ??= $this->getFirebaseCredentials();
            if (!$jsonKey) {
                return null;
            }

            $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
            $credentials = new ServiceAccountCredentials($scopes, $jsonKey);

            $token = $credentials->fetchAuthToken(HttpHandlerFactory::build());

            return $token['access_token'] ?? null;
        } catch (\Exception $e) {
            Log::error('Gagal generate FCM access token: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Resolve project ID for FCM endpoint.
     *
     * Accepts common misconfigurations such as:
     * - projects/my-project-id
     * - https://fcm.googleapis.com/v1/projects/my-project-id/messages:send
     */
    private function resolveProjectId(?array $jsonKey = null): ?string
    {
        $jsonKey ??= $this->getFirebaseCredentials();

        $projectId = trim((string) config('firebase.fcm.project_id', ''));

        if (preg_match('#fcm\.googleapis\.com/v1/projects/([^/]+)#', $projectId, $matches) === 1) {
            $projectId = $matches[1];
        }

        if (str_starts_with($projectId, 'projects/')) {
            $projectId = substr($projectId, strlen('projects/'));
        }

        $projectId = trim($projectId, " \t\n\r\0\x0B/");

        if ($projectId === '' && !empty($jsonKey['project_id'])) {
            $projectId = trim((string) $jsonKey['project_id']);
        }

        if ($projectId === '') {
            Log::error('FIREBASE_PROJECT_ID not set and could not be inferred from credentials');
            return null;
        }

        return $projectId;
    }

    /**
     * Send push notification via Firebase Cloud Messaging (HTTP v1)
     */
    public function sendPushNotification(User $user, string $title, string $body, array $data = []): bool
    {
        if (!$user->fcm_token) {
            Log::warning('User tidak memiliki FCM token', ['user_id' => $user->id]);
            return false;
        }

        $jsonKey = $this->getFirebaseCredentials();
        if (!$jsonKey) {
            return false;
        }

        $accessToken = $this->getAccessToken($jsonKey);
        if (!$accessToken) {
            return false;
        }

        $projectId = $this->resolveProjectId($jsonKey);
        if (!$projectId) {
            return false;
        }

        try {
            // Ensure all data values are strings (required by FCM v1)
            $formattedData = [];
            foreach ($data as $key => $value) {
                $formattedData[(string)$key] = (string)$value;
            }

            $endpoint = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

            $response = Http::withToken($accessToken)
                ->post($endpoint, [
                    'message' => [
                        'token' => $user->fcm_token,
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        'data' => $formattedData,
                        'android' => [
                            'priority' => 'high',
                            'notification' => [
                                'sound' => 'default',
                                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                                'icon' => 'ic_launcher',
                            ],
                        ],
                        'apns' => [
                            'payload' => [
                                'aps' => [
                                    'sound' => 'default',
                                ],
                            ],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                Log::info('Push notification (v1) terkirim', [
                    'user_id' => $user->id,
                    'fcm_token' => substr($user->fcm_token, 0, 20) . '...',
                ]);
                return true;
            } else {
                Log::error('Gagal mengirim push notification (v1)', [
                    'user_id' => $user->id,
                    'project_id' => $projectId,
                    'endpoint' => $endpoint,
                    'status' => $response->status(),
                    'response' => $response->body(),
                ]);
                return false;
            }
        } catch (\Exception $e) {
            Log::error('Error saat mengirim push notification (v1)', [
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
     * Send push notification to all active users
     */
    public function sendPushToAll(string $title, string $body, array $data = []): int
    {
        $users = User::where('is_active', true)
            ->whereNotNull('fcm_token')
            ->get();

        $count = 0;
        foreach ($users as $user) {
            // Create record in database
            Notification::create([
                'user_id' => $user->id,
                'type'    => $data['type'] ?? 'broadcast',
                'title'   => $title,
                'body'    => $body,
                'data'    => $data,
                'status'  => 'pending',
            ]);

            // Send push
            if ($this->sendPushNotification($user, $title, $body, $data)) {
                $count++;
            }
        }

        return $count;
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
