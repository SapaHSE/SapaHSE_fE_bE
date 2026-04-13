<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\ChecklistItem;
use App\Models\ReadStatus;
use App\Models\Report;
use App\Models\ReportLog;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ReportController extends Controller
{
    protected $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }
    // GET /api/reports
    // Filter  : ?type=hazard|inspection &severity=low|medium|high &status=open|in_progress|closed
    // Search  : ?search=keyword
    // Sort    : ?sort=oldest
    // Paginate: ?page=1&per_page=10
    public function index(Request $request)
    {
        $query  = Report::with(['user', 'checklistItems'])->latest();
        $userId = Auth::id();

        if ($request->filled('type'))       $query->where('type', $request->type);
        if ($request->filled('severity'))   $query->where('severity', $request->severity);
        if ($request->filled('status'))     $query->where('status', $request->status);
        if ($request->filled('department')) $query->where('reported_department', $request->department);
        if ($request->filled('area'))       $query->where('area', $request->area);

        if ($request->filled('search')) {
            $s = $request->search;
            $query->where(fn($q) => $q
                ->where('title', 'like', "%{$s}%")
                ->orWhere('description', 'like', "%{$s}%")
                ->orWhere('location', 'like', "%{$s}%")
            );
        }

        if ($request->input('sort') === 'oldest') {
            $query->oldest();
        }

        $perPage  = (int) $request->input('per_page', 10);
        $paginate = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'meta'   => [
                'total'        => $paginate->total(),
                'per_page'     => $paginate->perPage(),
                'current_page' => $paginate->currentPage(),
                'last_page'    => $paginate->lastPage(),
                'has_more'     => $paginate->hasMorePages(),
            ],
            'data' => $paginate->map(fn($r) => $this->formatReport($r, $userId)),
        ]);
    }

    // GET /api/reports/statistics
    public function statistics(Request $request)
    {
        $query = Report::query();

        // Apply filters
        if ($request->filled('type'))       $query->where('type', $request->type);
        if ($request->filled('status'))     $query->where('status', $request->status);
        
        if ($request->filled('start_date') && $request->filled('end_date')) {
            $query->whereBetween('created_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date . ' 23:59:59'
            ]);
        }

        // We clone to get accurate aggregated counts before pagination
        $baseQuery = clone $query;

        $stats = [
            'total'       => (clone $baseQuery)->count(),
            'hazard'      => (clone $baseQuery)->where('type', 'hazard')->count(),
            'inspection'  => (clone $baseQuery)->where('type', 'inspection')->count(),
            'open'        => (clone $baseQuery)->where('status', 'open')->count(),
            'in_progress' => (clone $baseQuery)->where('status', 'in_progress')->count(),
            'closed'      => (clone $baseQuery)->where('status', 'closed')->count(),
            'high'        => (clone $baseQuery)->where('severity', 'high')->count(),
            'medium'      => (clone $baseQuery)->where('severity', 'medium')->count(),
            'low'         => (clone $baseQuery)->where('severity', 'low')->count(),
        ];

        // Also return the latest filtered reports for the table
        $perPage  = (int) $request->input('per_page', 50);
        $paginate = $query->with(['user'])->latest()->paginate($perPage);
        $data = $paginate->map(fn($r) => $this->formatReport($r, Auth::id()));

        return response()->json([
            'status' => 'success',
            'stats'  => $stats,
            'data'   => $data,
            'meta'   => [
                'total'        => $paginate->total(),
                'per_page'     => $paginate->perPage(),
                'current_page' => $paginate->currentPage(),
            ],
        ]);
    }

    // POST /api/reports
    public function store(Request $request)
    {
        $request->validate([
            // ── Shared ──────────────────────────────────────────────────────
            'type'        => 'required|in:hazard,inspection',
            'title'       => 'required|string|max:200',
            'description' => 'required|string',
            'location'    => 'required|string|max:200',
            'image'       => 'nullable|image|max:4096',

            // ── Hazard-only ─────────────────────────────────────────────────
            'severity'            => 'required_if:type,hazard|nullable|in:low,medium,high',
            'name_pja'            => 'nullable|string|max:100',
            'reported_department' => 'nullable|string|max:100',

            // ── Inspection-only ─────────────────────────────────────────────
            'area'      => 'required_if:type,inspection|nullable|string|max:100',
            'result'    => 'required_if:type,inspection|nullable|in:compliant,non_compliant,needs_follow_up',
            'notes'     => 'nullable|string',

            // ── Checklist (inspection only) ─────────────────────────────────
            'checklist'         => 'nullable|array',
            'checklist.*.label' => 'required_with:checklist|string|max:255',
        ]);

        // Handle image upload
        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('reports', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $report = Report::create([
            'user_id'             => Auth::id(),
            'type'                => $request->type,
            'title'               => $request->title,
            'description'         => $request->description,
            'status'              => 'open',
            'location'            => $request->location,
            'image_url'           => $imageUrl,
            // Hazard fields
            'severity'            => $request->type === 'hazard' ? $request->severity : null,
            'name_pja'            => $request->type === 'hazard' ? $request->name_pja : null,
            'reported_department' => $request->type === 'hazard' ? $request->reported_department : null,
            // Inspection fields
            'area'    => $request->type === 'inspection' ? $request->area : null,
            'result'  => $request->type === 'inspection' ? $request->result : null,
            'notes'   => $request->type === 'inspection' ? $request->notes : null,
        ]);

        // Save checklist items (inspection only)
        if ($request->type === 'inspection' && $request->filled('checklist')) {
            foreach ($request->checklist as $index => $item) {
                ChecklistItem::create([
                    'report_id'  => $report->id,
                    'label'      => $item['label'],
                    'is_checked' => filter_var($item['is_checked'] ?? false, FILTER_VALIDATE_BOOLEAN),
                    'sort_order' => $index,
                ]);
            }
        }

        // Add initial log
        ReportLog::create([
            'report_id' => $report->id,
            'user_id'   => Auth::id(),
            'status'    => 'open',
            'message'   => $request->type === 'hazard' ? 'Laporan hazard baru dibuat.' : 'Laporan inspeksi baru dibuat.',
        ]);

        $report->load(['user', 'checklistItems']);

        // ── Notifikasi otomatis ke Admin & Superadmin ──────────────────────
        try {
            $admins = User::whereIn('role', ['admin', 'superadmin'])->get();
            $creatorName = $report->user->full_name ?? 'User';
            $typeLabel = ucfirst($report->type);

            foreach ($admins as $admin) {
                /** @var User $admin */
                $this->notificationService->createNotification(
                    $admin,
                    'hazard', // categorized as hazard/system
                    "Laporan $typeLabel Baru",
                    "$creatorName telah mengirim laporan: {$report->title}",
                    ['report_id' => $report->id, 'type' => $report->type]
                );
            }
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Gagal kirim notifikasi admin: ' . $e->getMessage());
        }

        return response()->json([
            'status'  => 'success',
            'message' => $request->type === 'hazard'
                ? 'Laporan hazard berhasil dikirim.'
                : 'Laporan inspeksi berhasil dikirim.',
            'data' => $this->formatReport($report, Auth::id()),
        ], 201);
    }

    // GET /api/reports/{id}
    public function show(string $id)
    {
        $userId = Auth::id();
        $report = Report::with(['user', 'checklistItems'])->findOrFail($id);

        // Auto mark as read
        ReadStatus::firstOrCreate([
            'user_id'   => $userId,
            'item_id'   => $report->id,
            'item_type' => 'report',
        ], ['read_at' => now()]);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatReport($report, $userId),
        ]);
    }

    // DELETE /api/reports/{id}
    public function destroy(string $id)
    {
        $report = Report::findOrFail($id);
        $user   = Auth::user();

        if ($report->user_id !== $user->id && $user->role !== 'admin' && $user->role !== 'superadmin') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Anda tidak memiliki akses untuk menghapus laporan ini.',
            ], 403);
        }

        $report->checklistItems()->delete();
        $report->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Laporan berhasil dihapus.',
        ]);
    }

    // PATCH /api/reports/{id}/status  (admin only)
    public function updateStatus(Request $request, string $id)
    {
        $request->validate([
            'status'     => 'required|in:open,in_progress,closed',
            'sub_status' => 'nullable|string|max:50',
            'message'    => 'nullable|string',
            'image'      => 'nullable|image|max:8192', // Max 8MB
        ]);

        // Custom validation: executing or reviewing REQUIRES an image
        if (in_array($request->sub_status, ['executing', 'reviewing']) && !$request->hasFile('image')) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Melampirkan foto wajib untuk status ' . ucfirst($request->sub_status),
            ], 422);
        }

        $report = Report::findOrFail($id);
        
        // Prevent backward status transitions
        $statusLevels = [
            'open'        => 0,
            'in_progress' => 1,
            'closed'      => 2
        ];
        
        $currentLevel = $statusLevels[$report->status] ?? 0;
        $newLevel     = $statusLevels[$request->status] ?? 0;
        
        if ($newLevel < $currentLevel) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Status tidak dapat dikembalikan ke tahap sebelumnya.',
            ], 422);
        }

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('report_logs', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $report->update([
            'status'     => $request->status,
            'sub_status' => $request->sub_status,
        ]);

        ReportLog::create([
            'report_id'  => $report->id,
            'user_id'    => Auth::id(),
            'status'     => $request->status,
            'sub_status' => $request->sub_status,
            'message'    => $request->message ?? "Status diubah menjadi {$request->status} - {$request->sub_status}",
            'image_url'  => $imageUrl,
        ]);

        // ── Notifikasi otomatis ke Pembuat Laporan ──────────────────────────
        try {
            /** @var User $reporter */
            $reporter = $report->user;
            
            $this->notificationService->createNotification(
                $reporter,
                'status_update',
                "Pembaruan Status Laporan",
                "Status laporan '{$report->title}' Anda telah diubah menjadi " . strtoupper($request->status),
                ['report_id' => $report->id, 'status' => $request->status]
            );
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Gagal kirim notifikasi user: ' . $e->getMessage());
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'Status laporan berhasil diperbarui.',
            'data'    => $this->formatReport($report->fresh(['user', 'checklistItems']), Auth::id()),
        ]);
    }

    // GET /api/reports/{id}/logs
    public function logs(string $id)
    {
        $report = Report::findOrFail($id);
        $logs = ReportLog::where('report_id', $id)
            ->with(['user'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data'   => $logs->map(fn($log) => [
                'id'         => $log->id,
                'status'     => $log->status,
                'sub_status' => $log->sub_status,
                'message'    => $log->message,
                'image_url'  => $log->image_url,
                'user_name'  => $log->user->full_name ?? 'System',
                'created_at' => $log->created_at->format('Y-m-d H:i:s'),
                'date_human' => $log->created_at->format('d M Y, H:i'),
            ])
        ]);
    }

    private function formatReport(Report $report, ?string $userId): array
    {
        $base = [
            'id'          => $report->id,
            'type'        => $report->type,
            'title'       => $report->title,
            'description' => $report->description,
            'status'      => $report->status,
            'sub_status'  => $report->sub_status,
            'location'    => $report->location,
            'image_url'   => $report->image_url,
            'is_read'     => $userId ? $report->isReadBy($userId) : false,
            'reported_by' => $report->user ? [
                'full_name'  => $report->user->full_name,
                'employee_id'   => $report->user->employee_id,
                'department' => $report->user->department,
                'company'    => $report->user->company,
            ] : null,
            'created_at'  => $report->created_at,
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
}