<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function __construct(protected NotificationService $notificationService)
    {
    }

    /**
     * Register FCM token dari mobile app
     */
    public function registerFcmToken(Request $request): JsonResponse
    {
        $request->validate([
            'fcm_token' => 'required|string',
        ]);

        $user = $request->user();
        $user->update([
            'fcm_token' => $request->fcm_token,
        ]);

        return response()->json([
            'message' => 'FCM token berhasil didaftarkan',
            'data' => [
                'user_id' => $user->id,
                'fcm_token' => substr($user->fcm_token, 0, 20) . '...',
            ],
        ]);
    }

    /**
     * Get notifikasi user
     */
    public function getNotifications(Request $request): JsonResponse
    {
        $user = $request->user();

        $notifications = Notification::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'message' => 'Notifikasi berhasil diambil',
            'data' => $notifications,
        ]);
    }

    /**
     * Get single notification
     */
    public function getNotification(Notification $notification): JsonResponse
    {
        $user = auth('sanctum')->user();

        if ($notification->user_id !== $user->id) {
            return response()->json([
                'message' => 'Unauthorized',
            ], 403);
        }

        return response()->json([
            'message' => 'Notifikasi berhasil diambil',
            'data' => $notification,
        ]);
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Notification $notification): JsonResponse
    {
        $user = auth('sanctum')->user();

        if ($notification->user_id !== $user->id) {
            return response()->json([
                'message' => 'Unauthorized',
            ], 403);
        }

        $this->notificationService->markAsRead($notification);

        return response()->json([
            'message' => 'Notifikasi berhasil ditandai sebagai dibaca',
            'data' => $notification,
        ]);
    }

    /**
     * Update last activity user
     */
    public function updateActivity(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->notificationService->updateLastActivity($user);

        return response()->json([
            'message' => 'Activity berhasil diupdate',
            'data' => [
                'user_id' => $user->id,
                'last_activity_at' => $user->last_activity_at,
            ],
        ]);
    }

    /**
     * Get notifikasi yang belum dibaca
     */
    public function getUnreadCount(): JsonResponse
    {
        $user = auth('sanctum')->user();

        $unreadCount = Notification::where('user_id', $user->id)
            ->where('status', '!=', 'read')
            ->count();

        return response()->json([
            'message' => 'Unread count berhasil diambil',
            'data' => [
                'unread_count' => $unreadCount,
            ],
        ]);
    }
}

