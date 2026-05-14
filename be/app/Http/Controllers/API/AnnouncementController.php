<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\ReadStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class AnnouncementController extends Controller
{
    public function index(Request $request)
    {
        $userId        = Auth::id();
        $perPage       = (int) $request->input('per_page', 10);
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

    public function show($id)
    {
        $announcement = Announcement::active()->with('creator')->findOrFail($id);
        $userId       = Auth::id();

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

    public function store(Request $request)
    {
        $validated = $request->validate([
            'title'     => 'required|string|max:200',
            'body'      => 'required|string',
            'is_urgent' => 'sometimes|boolean',
            'image'     => 'sometimes|file|image|max:5120',
        ]);

        $imagePath = null;
        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('announcements', 'public');
        }

        $announcement = Announcement::create([
            'created_by' => Auth::id(),
            'title'      => $validated['title'],
            'body'       => $validated['body'],
            'is_active'  => true,
            'is_urgent'  => filter_var($validated['is_urgent'] ?? false, FILTER_VALIDATE_BOOLEAN),
            'image_url'  => $imagePath,
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Announcement created successfully',
            'data'    => $this->formatAnnouncement($announcement->load('creator'), Auth::id(), true),
        ], 201);
    }

    public function destroy($id)
    {
        $announcement = Announcement::findOrFail($id);

        if ($announcement->image_url) {
            Storage::disk('public')->delete($announcement->image_url);
        }

        $announcement->update(['is_active' => false]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Announcement deactivated successfully',
        ]);
    }

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

    private function resolveFileUrl(?string $filePath): ?string
    {
        if ($filePath === null || trim($filePath) === '') {
            return null;
        }

        return filter_var($filePath, FILTER_VALIDATE_URL)
            ? $filePath
            : asset('storage/' . $filePath);
    }

    private function formatAnnouncement(Announcement $a, string $userId, bool $withBody = false): array
    {
        $data = [
            'id'         => $a->id,
            'title'      => $a->title,
            'is_urgent'  => $a->is_urgent,
            'image_url'  => $this->resolveFileUrl($a->image_url),
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