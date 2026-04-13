<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class NotificationController extends Controller
{
    /**
     * GET /api/notifications — daftar notifikasi user yang login
     */
    public function getNotifications(Request $request): JsonResponse
    {
        $user = $request->user();

        $notifications = Notification::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->paginate((int) $request->input('per_page', 20));

        return response()->json([
            'status'       => 'success',
            'unread_count' => Notification::where('user_id', $user->id)
                ->where('status', '!=', 'read')
                ->count(),
            'meta' => [
                'total'        => $notifications->total(),
                'per_page'     => $notifications->perPage(),
                'current_page' => $notifications->currentPage(),
                'last_page'    => $notifications->lastPage(),
                'has_more'     => $notifications->hasMorePages(),
            ],
            'data' => $notifications->items(),
        ]);
    }

    /**
     * GET /api/notifications/{id}
     */
    public function getNotification(Notification $notification): JsonResponse
    {
        if ($notification->user_id !== Auth::id()) {
            return response()->json(['status' => 'error', 'message' => 'Unauthorized'], 403);
        }

        return response()->json([
            'status' => 'success',
            'data'   => $notification,
        ]);
    }

    /**
     * POST /api/notifications/{id}/read
     */
    public function markAsRead(Notification $notification): JsonResponse
    {
        if ($notification->user_id !== Auth::id()) {
            return response()->json(['status' => 'error', 'message' => 'Unauthorized'], 403);
        }

        $notification->update(['status' => 'read', 'read_at' => now()]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Notifikasi berhasil ditandai sebagai dibaca',
            'data'    => $notification,
        ]);
    }

    /**
     * POST /api/notifications/read-all — tandai semua sebagai dibaca
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->where('status', '!=', 'read')
            ->update(['status' => 'read', 'read_at' => now()]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Semua notifikasi telah ditandai sebagai dibaca',
        ]);
    }

    /**
     * GET /api/notifications/unread/count
     */
    public function getUnreadCount(): JsonResponse
    {
        $unreadCount = Notification::where('user_id', Auth::id())
            ->where('status', '!=', 'read')
            ->count();

        return response()->json([
            'status' => 'success',
            'data'   => ['unread_count' => $unreadCount],
        ]);
    }

    /**
     * POST /api/notifications/register-fcm
     */
    public function registerFcmToken(Request $request): JsonResponse
    {
        $request->validate(['fcm_token' => 'required|string']);

        $user = $request->user();
        $user->update(['fcm_token' => $request->fcm_token]);

        return response()->json([
            'status'  => 'success',
            'message' => 'FCM token berhasil didaftarkan',
        ]);
    }
}

