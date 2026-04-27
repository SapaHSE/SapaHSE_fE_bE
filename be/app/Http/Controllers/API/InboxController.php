<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\ReadStatus;
use App\Models\HazardReport;
use App\Models\InspectionReport;
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
        $readHazardIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'hazard_report')
            ->pluck('item_id');
        
        $readInspectionIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'inspection_report')
            ->pluck('item_id');

        // Personal: reports where user is PJA, Inspector, or tagged
        $personalHazardUnread = HazardReport::where(function($q) use ($user) {
                $q->where('pic_department', 'like', '%' . $user->full_name . '%');
            })
            ->where('status', '!=', 'pending')
            ->whereNotIn('id', $readHazardIds)
            ->count();
            
        $personalInspectionUnread = InspectionReport::where(function($q) use ($user) {
                $q->where('name_inspector', $user->full_name);
            })
            ->where('status', '!=', 'pending')
            ->whereNotIn('id', $readInspectionIds)
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
            $data  = $paged->getCollection()->map(fn($a) => $this->formatAnnouncement($a, $userId));

        } else {
            // Gabungkan Hazard dan Inspection yang relevan, exclude pending (hanya tampil setelah approved)
            $hQuery = HazardReport::with(['user'])
                ->where('pic_department', 'like', '%' . $user->full_name . '%')
                ->where('status', '!=', 'pending');
            $iQuery = InspectionReport::with(['user', 'checklistItems'])
                ->where('name_inspector', $user->full_name)
                ->where('status', '!=', 'pending');

            if ($isRead !== null) {
                if ($isRead) {
                    $hQuery->whereIn('id', $readHazardIds);
                    $iQuery->whereIn('id', $readInspectionIds);
                } else {
                    $hQuery->whereNotIn('id', $readHazardIds);
                    $iQuery->whereNotIn('id', $readInspectionIds);
                }
            }

            if ($search) {
                $searchCallback = function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('description', 'like', "%{$search}%")
                      ->orWhere('location', 'like', "%{$search}%");
                };
                $hQuery->where($searchCallback);
                $iQuery->where($searchCallback);
            }

            // Gabungkan hasil (ini manual gabung karena beda tabel)
            $hazards = $hQuery->get()->map(function(HazardReport $r) use ($userId) {
                return $this->formatHazard($r, $userId);
            });
            $inspections = $iQuery->get()->map(function(InspectionReport $r) use ($userId) {
                return $this->formatInspection($r, $userId);
            });

            $merged = $hazards->concat($inspections)->sortByDesc('created_at')->values();
            
            // Manual pagination for merged collection
            $currentPage = $request->input('page', 1);
            $pagedData = $merged->forPage($currentPage, $perPage);
            
            $data = $pagedData;
            $totalMerged = $merged->count();
            
            // Re-mocking pagination object values for response
            $metaExtra = [
                'total'        => $totalMerged,
                'per_page'     => $perPage,
                'current_page' => (int)$currentPage,
                'last_page'    => ceil($totalMerged / $perPage),
                'has_more'     => ($currentPage * $perPage) < $totalMerged,
            ];
        }

        return response()->json([
            'status'       => 'success',
            'unread_count' => [
                'total'         => $personalHazardUnread + $personalInspectionUnread + $unreadAnnouncementsCount,
                'personal'      => $personalHazardUnread + $personalInspectionUnread,
                'announcements' => $unreadAnnouncementsCount,
            ],
            'meta' => isset($metaExtra) ? $metaExtra : [
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
            'item_type' => 'required|in:hazard_report,inspection_report,announcement',
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

        // Mark all hazards
        foreach (HazardReport::pluck('id') as $id) {
            ReadStatus::firstOrCreate([
                'user_id'   => $userId,
                'item_id'   => $id,
                'item_type' => 'hazard_report',
            ], ['read_at' => now()]);
        }

        // Mark all inspections
        foreach (InspectionReport::pluck('id') as $id) {
            ReadStatus::firstOrCreate([
                'user_id'   => $userId,
                'item_id'   => $id,
                'item_type' => 'inspection_report',
            ], ['read_at' => now()]);
        }

        // Mark all announcements
        foreach (Announcement::active()->pluck('id') as $id) {
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

    private function formatHazard(HazardReport $report, ?string $userId): array
    {
        return [
            'id'                  => $report->id,
            'item_type'           => 'hazard_report',
            'ticket_number'       => $report->ticket_number,
            'title'               => $report->title,
            'description'         => $report->description,
            'status'              => $report->status,
            'location'            => $report->location,
            'image_url'           => $report->image_url,
            'is_read'             => $userId ? $report->isReadBy($userId) : false,
            'reported_by'         => $report->user ? $report->user->only(['full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'          => $report->created_at?->toIso8601String(),
            'time_ago'            => $report->created_at?->diffForHumans(),
            'severity'            => $report->severity,
            'pic_department'      => $report->pic_department,
            'pelaku_pelanggaran'  => $report->pelaku_pelanggaran,
            'reported_department' => $report->reported_department,
            'hazard_category'     => $report->hazard_category,
            'hazard_subcategory'  => $report->hazard_subcategory,
            'suggestion'          => $report->suggestion,
        ];
    }

    private function formatInspection(InspectionReport $report, ?string $userId): array
    {
        return [
            'id'              => $report->id,
            'item_type'       => 'inspection_report',
            'ticket_number'   => $report->ticket_number,
            'title'           => $report->title,
            'description'     => $report->description,
            'status'          => $report->status,
            'location'        => $report->location,
            'image_url'       => $report->image_url,
            'is_read'         => $userId ? $report->isReadBy($userId) : false,
            'reported_by'     => $report->user ? $report->user->only(['full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'      => $report->created_at?->toIso8601String(),
            'time_ago'        => $report->created_at?->diffForHumans(),
            'area'            => $report->area,
            'name_inspector'  => $report->name_inspector,
            'result'          => $report->result,
            'notes'           => $report->notes,
            'checklist_items' => $report->checklistItems->map(fn($item) => $item->only(['id', 'label', 'is_checked', 'sort_order'])),
        ];
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
            'from'      => $creatorName,
            'from_name' => $creatorName,
            'is_read'   => $userId ? $a->isReadBy($userId) : false,
            'created_by' => $a->creator ? $a->creator->only(['full_name', 'position']) : null,
            'created_at' => $a->created_at?->toIso8601String(),
            'time_ago'   => $a->created_at?->diffForHumans(),
        ];
    }
}