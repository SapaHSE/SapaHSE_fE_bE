<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\ReadStatus;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class InboxController extends Controller
{
    // GET /api/inbox
    // Menggabungkan reports + announcements dalam satu feed
    // Filter: ?type=report|announcement &is_read=0|1
    // Paginate: ?page=1&per_page=15
    public function index(Request $request)
    {
        $userId  = Auth::id();
        $type    = $request->get('type');      // filter by type
        $isRead  = $request->filled('is_read') ? (bool) $request->is_read : null;
        $perPage = (int) $request->get('per_page', 15);
        $page    = (int) $request->get('page', 1);

        $items = collect();

        // ── Ambil Reports ─────────────────────────────────────────────────────
        if (! $type || $type === 'report') {
            $reports = Report::with('user')->get()->map(function ($report) use ($userId) {
                $isRead = $report->isReadBy($userId);
                return [
                    'id'          => $report->id,
                    'item_type'   => 'report',
                    'title'       => $report->title,
                    'subtitle'    => $report->location,
                    'type'        => $report->type,        // hazard | inspection
                    'severity'    => $report->severity,
                    'status'      => $report->status,
                    'name_pja'    => $report->name_pja,
                    'reported_department' => $report->reported_department,
                    'is_read'     => $isRead,
                    'reported_by' => $report->user ? [
                        'full_name'   => $report->user->full_name,
                        'employee_id' => $report->user->employee_id,
                        'department'  => $report->user->department,
                    ] : null,
                    'created_at'  => $report->created_at,
                    'time_ago'    => $report->created_at?->diffForHumans(),
                ];
            });
            $items = $items->merge($reports);
        }

        // ── Ambil Announcements ───────────────────────────────────────────────
        if (! $type || $type === 'announcement') {
            $announcements = Announcement::active()->with('creator')->get()->map(function ($a) use ($userId) {
                $isRead = $a->isReadBy($userId);
                return [
                    'id'        => $a->id,
                    'item_type' => 'announcement',
                    'title'     => $a->title,
                    'subtitle'  => $a->creator?->full_name ?? 'Admin',
                    'is_read'   => $isRead,
                    'created_by'=> $a->creator ? [
                        'full_name' => $a->creator->full_name,
                        'position'  => $a->creator->position,
                    ] : null,
                    'created_at' => $a->created_at,
                    'time_ago'   => $a->created_at?->diffForHumans(),
                ];
            });
            $items = $items->merge($announcements);
        }

        // ── Filter is_read ────────────────────────────────────────────────────
        if (! is_null($isRead)) {
            $items = $items->filter(fn($i) => $i['is_read'] === $isRead);
        }

        // ── Sort by latest ────────────────────────────────────────────────────
        $items = $items->sortByDesc('created_at')->values();

        // ── Hitung unread ─────────────────────────────────────────────────────
        $unreadReports       = Report::all()->filter(fn($r) => ! $r->isReadBy($userId))->count();
        $allAnnouncementIds  = Announcement::active()->pluck('id');
        $readAnnouncementIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'announcement')
            ->pluck('item_id');
        $unreadAnnouncements = $allAnnouncementIds->diff($readAnnouncementIds)->count();

        // ── Manual Pagination ─────────────────────────────────────────────────
        $total   = $items->count();
        $offset  = ($page - 1) * $perPage;
        $paged   = $items->slice($offset, $perPage)->values();

        // Format created_at jadi string sebelum return
        $paged = $paged->map(function ($item) {
            $item['created_at'] = isset($item['created_at'])
                ? \Carbon\Carbon::parse($item['created_at'])->toDateTimeString()
                : null;
            return $item;
        });

        return response()->json([
            'status'       => 'success',
            'unread_count' => [
                'total'         => $unreadReports + $unreadAnnouncements,
                'reports'       => $unreadReports,
                'announcements' => $unreadAnnouncements,
            ],
            'meta' => [
                'total'        => $total,
                'per_page'     => $perPage,
                'current_page' => $page,
                'last_page'    => (int) ceil($total / $perPage),
                'has_more'     => ($offset + $perPage) < $total,
            ],
            'data' => $paged,
        ]);
    }

    // POST /api/inbox/read
    // Mark satu item sebagai sudah dibaca
    // Body: { "item_id": "uuid", "item_type": "report|announcement" }
    public function markAsRead(Request $request)
    {
        $request->validate([
            'item_id'   => 'required|string',
            'item_type' => 'required|in:report,announcement',
        ]);

        ReadStatus::firstOrCreate([
            'user_id'   => Auth::id(),
            'item_id'   => $request->item_id,
            'item_type' => $request->item_type,
        ], ['read_at' => now()]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Item marked as read',
        ]);
    }

    // POST /api/inbox/read-all
    // Mark semua reports & announcements sebagai sudah dibaca
    public function markAllAsRead()
    {
        $userId = Auth::id();

        // Mark semua reports
        $reportIds = Report::pluck('id');
        foreach ($reportIds as $id) {
            ReadStatus::firstOrCreate([
                'user_id'   => $userId,
                'item_id'   => $id,
                'item_type' => 'report',
            ], ['read_at' => now()]);
        }

        // Mark semua announcements
        $announcementIds = Announcement::active()->pluck('id');
        foreach ($announcementIds as $id) {
            ReadStatus::firstOrCreate([
                'user_id'   => $userId,
                'item_id'   => $id,
                'item_type' => 'announcement',
            ], ['read_at' => now()]);
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'All items marked as read',
        ]);
    }
}
