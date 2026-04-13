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
    public function index(Request $request)
    {
        $user    = Auth::user();
        $userId  = $user->id;
        $type    = $request->input('type', 'personal'); // 'personal' | 'announcement'
        $isRead  = $request->filled('is_read') ? filter_var($request->is_read, FILTER_VALIDATE_BOOLEAN) : null;
        $search  = $request->input('search');
        $perPage = (int) $request->input('per_page', 15);

        // ── 1. Hitung unread badges ────────────────────────────────────────────
        $readReportIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'report')
            ->pluck('item_id');

        // Personal: hanya laporan yang name_pja == full_name user login
        $personalUnread = Report::where('name_pja', $user->full_name)
            ->whereNotIn('id', $readReportIds)
            ->count();

        $readAnnouncementIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'announcement')
            ->pluck('item_id');
        $unreadAnnouncementsCount = Announcement::active()
            ->whereNotIn('id', $readAnnouncementIds)
            ->count();

        // ── 2. Fetch data sesuai tab ───────────────────────────────────────────
        if ($type === 'announcement') {
            $query = Announcement::active()->with('creator');

            if ($isRead !== null) {
                if ($isRead) {
                    $query->whereIn('id', $readAnnouncementIds);
                } else {
                    $query->whereNotIn('id', $readAnnouncementIds);
                }
            }

            if ($search) {
                $query->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('body', 'like', "%{$search}%");
                });
            }

            $paged = $query->latest()->paginate($perPage);
            $data  = $paged->map(fn($a) => $this->formatAnnouncement($a, $userId));

        } else {
            // type = personal: laporan yang name_pja = full_name user yang login
            $query = Report::with(['user', 'checklistItems'])
                ->where('name_pja', $user->full_name);

            if ($isRead !== null) {
                if ($isRead) {
                    $query->whereIn('id', $readReportIds);
                } else {
                    $query->whereNotIn('id', $readReportIds);
                }
            }

            if ($search) {
                $query->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('description', 'like', "%{$search}%")
                      ->orWhere('location', 'like', "%{$search}%");
                });
            }

            $paged = $query->latest()->paginate($perPage);
            $data  = $paged->map(fn($r) => $this->formatReport($r, $userId));
        }

        return response()->json([
            'status'       => 'success',
            'unread_count' => [
                'total'         => $personalUnread + $unreadAnnouncementsCount,
                'personal'      => $personalUnread,
                'announcements' => $unreadAnnouncementsCount,
            ],
            'meta' => [
                'total'        => $paged->total(),
                'per_page'     => $paged->perPage(),
                'current_page' => $paged->currentPage(),
                'last_page'    => $paged->lastPage(),
                'has_more'     => $paged->hasMorePages(),
            ],
            'data' => $data,
        ]);
    }

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

    public function markAllAsRead()
    {
        $userId = Auth::id();

        // Mark all reports
        $reportIds = Report::pluck('id');
        foreach ($reportIds as $id) {
            ReadStatus::firstOrCreate([
                'user_id'   => $userId,
                'item_id'   => $id,
                'item_type' => 'report',
            ], ['read_at' => now()]);
        }

        // Mark all announcements
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

    private function formatReport(Report $report, ?string $userId): array
    {
        $base = [
            'id'          => $report->id,
            'item_type'   => 'report',
            'type'        => $report->type,
            'title'       => $report->title,
            'description' => $report->description,
            'status'      => $report->status,
            'location'    => $report->location,
            'image_url'   => $report->image_url,
            'is_read'     => $userId ? $report->isReadBy($userId) : false,
            'reported_by' => $report->user ? [
                'full_name'  => $report->user->full_name,
                'employee_id'   => $report->user->employee_id,
                'department' => $report->user->department,
                'company'    => $report->user->company,
            ] : null,
            'created_at'  => $report->created_at?->toIso8601String(),
            'time_ago'    => $report->created_at?->diffForHumans(),
        ];

        if ($report->type === 'hazard') {
            $base['severity']            = $report->severity;
            $base['name_pja']            = $report->name_pja;
            $base['reported_department'] = $report->reported_department;
        } else {
            $base['area']            = $report->area;
            $base['result']          = $report->result;
            $base['notes']           = $report->notes;
            $base['checklist_items'] = $report->checklistItems->map(fn($item) => [
                'id'         => $item->id,
                'label'      => $item->label,
                'is_checked' => $item->is_checked,
                'sort_order' => $item->sort_order,
            ])->values();
        }

        return $base;
    }

    private function formatAnnouncement(Announcement $a, ?string $userId): array
    {
        $creatorName = $a->creator?->full_name ?? 'Admin';

        return [
            'id'        => $a->id,
            'item_type' => 'announcement',
            'title'     => $a->title,
            'body'      => $a->body,
            'subtitle'  => $creatorName,
            'from'      => $creatorName,   // untuk Announcement.fromJson di Flutter
            'from_name' => $creatorName,   // alias
            'is_read'   => $userId ? $a->isReadBy($userId) : false,
            'created_by' => $a->creator ? [
                'full_name' => $a->creator->full_name,
                'position'  => $a->creator->position,
            ] : null,
            'created_at' => $a->created_at?->toIso8601String(),
            'time_ago'   => $a->created_at?->diffForHumans(),
        ];
    }
}
