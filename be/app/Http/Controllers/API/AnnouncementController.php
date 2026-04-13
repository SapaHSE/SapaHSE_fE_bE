<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\ReadStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AnnouncementController extends Controller
{
    // GET /api/announcements
    // Paginate: ?page=1&per_page=10
    public function index(Request $request)
    {
        $userId       = Auth::id();
        $perPage      = (int) $request->input('per_page', 10);
        $announcements = Announcement::active()->with('creator')->latest()->paginate($perPage);

        return response()->json([
            'status'       => 'success',
            'unread_count' => $this->unreadCount($userId),
            'meta'         => [
                'total'        => $announcements->total(),
                'per_page'     => $announcements->perPage(),
                'current_page' => $announcements->currentPage(),
                'last_page'    => $announcements->lastPage(),
                'has_more'     => $announcements->hasMorePages(),
            ],
            'data' => collect($announcements->items())->map(fn($a) => $this->formatAnnouncement($a, $userId, true)),
        ]);
    }

    // GET /api/announcements/{id} — auto mark as read
    public function show($id)
    {
        $announcement = Announcement::active()->with('creator')->findOrFail($id);
        $userId       = Auth::id();

        // Auto mark as read
        ReadStatus::firstOrCreate([
            'user_id'   => $userId,
            'item_id'   => $announcement->id,
            'item_type' => 'announcement',
        ], ['read_at' => now()]);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatAnnouncement($announcement, $userId, true),
        ]);
    }

    // POST /api/announcements (admin/supervisor only)
    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:200',
            'body'  => 'required|string',
        ]);

        $announcement = Announcement::create([
            'created_by' => Auth::id(),
            'title'      => $request->title,
            'body'       => $request->body,
            'is_active'  => true,
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Announcement created successfully',
            'data'    => $this->formatAnnouncement($announcement->load('creator'), Auth::id(), true),
        ], 201);
    }

    // DELETE /api/announcements/{id} (admin only)
    public function destroy($id)
    {
        $announcement = Announcement::findOrFail($id);
        $announcement->update(['is_active' => false]); // soft deactivate

        return response()->json([
            'status'  => 'success',
            'message' => 'Announcement deactivated successfully',
        ]);
    }

    // PATCH /api/announcements/read-all
    public function markAllAsRead()
    {
        $userId        = Auth::id();
        $announcements = Announcement::active()->pluck('id');

        foreach ($announcements as $id) {
            ReadStatus::firstOrCreate([
                'user_id'   => $userId,
                'item_id'   => $id,
                'item_type' => 'announcement',
            ], ['read_at' => now()]);
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'All announcements marked as read',
        ]);
    }

    private function unreadCount(string $userId): int
    {
        $allIds  = Announcement::active()->pluck('id');
        $readIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'announcement')
            ->pluck('item_id');

        return $allIds->diff($readIds)->count();
    }

    private function formatAnnouncement(Announcement $a, string $userId, bool $withBody = false): array
    {
        $data = [
            'id'         => $a->id,
            'title'      => $a->title,
            'is_read'    => $a->isReadBy($userId),
            'created_by' => $a->creator ? [
                'id'        => $a->creator->id,
                'full_name' => $a->creator->full_name,
                'position'  => $a->creator->position,
            ] : null,
            'created_at' => $a->created_at?->toDateTimeString(),
            'time_ago'   => $a->created_at?->diffForHumans(),
        ];

        if ($withBody) {
            $data['body'] = $a->body;
        }

        return $data;
    }
}
