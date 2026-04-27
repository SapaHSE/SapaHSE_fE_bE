<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\ChecklistItem;
use App\Models\InspectionReport;
use App\Models\ReadStatus;
use App\Models\ReportLog;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class InspectionReportController extends Controller
{
    protected $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    public function index(Request $request)
    {
        $query  = InspectionReport::with(['user', 'checklistItems'])->latest();
        $user   = Auth::user();
        $userId = $user->id;

        // Apply privacy filter: pending reports are visible only to the creator or admins
        if (!in_array($user->role, ['admin', 'superadmin'])) {
            $query->where(function ($q) use ($user) {
                $q->where('status', '!=', 'pending')
                ->orWhere('user_id', $user->id);
            });
        }

        if ($request->filled('status'))     $query->where('status', $request->status);
        if ($request->filled('area'))       $query->where('area', $request->area);

        if ($request->filled('search')) {
            $s = $request->search;
            $query->where(fn($q) => $q
                ->where('title', 'like', "%{$s}%")
                ->orWhere('description', 'like', "%{$s}%")
                ->orWhere('location', 'like', "%{$s}%")
                ->orWhere('ticket_number', 'like', "%{$s}%")
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

    public function store(Request $request)
    {
        $request->validate([
            'title'               => 'required|string|max:200',
            'description'         => 'required|string',
            'location'            => 'required|string|max:200',
            'image'               => 'nullable|image|max:4096',
            'company'             => 'nullable|string|max:150',
            'area'                => 'nullable|string|max:100',
            'inspector'           => 'nullable|string|max:150',
            'result'              => 'nullable|in:compliant,non_compliant,needs_follow_up',
            'notes'               => 'nullable|string',
            'checklist_items'     => 'nullable',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('reports', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $report = InspectionReport::create([
            'user_id'             => Auth::id(),
            'title'               => $request->title,
            'description'         => $request->description,
            'status'              => 'pending',
            'sub_status'          => 'validating',
            'location'            => $request->location,
            'image_url'           => $imageUrl,
            'company'             => $request->company ? strtoupper(trim($request->company)) : null,
            'area'                => $request->area,
            'name_inspector'      => $request->inspector,
            'result'              => $request->result,
            'notes'               => $request->notes,
        ]);

        $checklistRaw = $request->input('checklist_items');
        $checklistArray = [];
        if (is_string($checklistRaw)) {
            $checklistArray = json_decode($checklistRaw, true) ?? [];
        } elseif (is_array($checklistRaw)) {
            $checklistArray = $checklistRaw;
        }

        if (!empty($checklistArray)) {
            foreach ($checklistArray as $index => $item) {
                if (!empty($item['label'])) {
                    ChecklistItem::create([
                        'inspection_report_id' => $report->id,
                        'label'      => $item['label'],
                        'is_checked' => filter_var($item['checked'] ?? $item['is_checked'] ?? false, FILTER_VALIDATE_BOOLEAN),
                        'sort_order' => $index,
                    ]);
                }
            }
        }

        $report->logs()->create([
            'user_id'    => Auth::id(),
            'status'     => 'pending',
            'sub_status' => 'validating',
            'message'    => 'Laporan inspeksi baru dibuat dan sedang dalam proses validasi admin.',
        ]);

        $report->load(['user', 'checklistItems']);

        try {
            $admins = User::whereIn('role', ['admin', 'superadmin'])->get();
            $creatorName = $report->user->full_name ?? 'User';
            foreach ($admins as $admin) {
                /** @var \App\Models\User $admin */
                $this->notificationService->createNotification(
                    $admin, 'inspection', "Laporan Inspeksi Baru",
                    "$creatorName telah mengirim laporan: {$report->title}",
                    ['report_id' => $report->id, 'type' => 'inspection']
                );
            }
        } catch (\Exception $e) {}

        return response()->json([
            'status'  => 'success',
            'message' => 'Laporan inspeksi berhasil dikirim.',
            'data'    => $this->formatReport($report, Auth::id()),
        ], 201);
    }

    public function show(string $id)
    {
        $userId = Auth::id();
        $report = InspectionReport::with(['user', 'checklistItems'])->findOrFail($id);

        ReadStatus::firstOrCreate([
            'user_id'   => $userId,
            'item_id'   => $report->id,
            'item_type' => 'inspection_report',
        ], ['read_at' => now()]);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatReport($report, $userId),
        ]);
    }

    public function destroy(string $id)
    {
        $report = InspectionReport::findOrFail($id);
        $user = Auth::user();

        if ($report->user_id !== $user->id && !in_array($user->role, ['admin', 'superadmin'])) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
        }

        $report->checklistItems()->delete();
        $report->delete();
        return response()->json(['status' => 'success', 'message' => 'Laporan inspeksi berhasil dihapus.']);
    }

    public function updateStatus(Request $request, string $id)
    {
        $request->validate([
            'status'         => 'required|in:open,in_progress,closed,rejected',
            'sub_status'     => 'nullable|string|max:50',
            'message'        => 'nullable|string',
            'image'          => 'nullable|image|max:8192',
            'tagged_user_id' => 'nullable|uuid|exists:users,id',
        ]);

        $report = InspectionReport::findOrFail($id);
        $user = Auth::user();

        // Check if user is Admin, Superadmin, the original Reporter, or the Inspector
        $isInspector = $report->name_inspector && stripos($report->name_inspector, $user->full_name) !== false;
        $isAdmin = in_array($user->role, ['admin', 'superadmin']);
        $isReporter = $report->user_id === $user->id;

        if (!$isAdmin && !$isReporter && !$isInspector) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak. Anda tidak memiliki izin.'], 403);
        }

        $requestedStatus = $request->status;
        $normalizedStatus = $requestedStatus === 'rejected' ? 'closed' : $requestedStatus;
        $normalizedSubStatus = $request->sub_status;
        if ($requestedStatus === 'rejected' && !$normalizedSubStatus) {
            $normalizedSubStatus = 'rejected';
        }

        // Additional restrictions for non-admins
        if (!$isAdmin) {
            // Cannot select 'validating' or 'approved'
            if (in_array($normalizedSubStatus, ['validating', 'approved'])) {
                return response()->json(['status' => 'error', 'message' => 'Izin ditolak untuk status ini.'], 403);
            }
            // Cannot select final closed status (including explicit rejected request)
            if (in_array($requestedStatus, ['closed', 'rejected'])) {
                return response()->json(['status' => 'error', 'message' => 'Hanya Admin yang dapat menutup laporan.'], 403);
            }
        }

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('report_logs', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $report->update([
            'status'     => $normalizedStatus,
            'sub_status' => $normalizedSubStatus,
        ]);

        $report->logs()->create([
            'user_id'        => Auth::id(),
            'tagged_user_id' => $request->tagged_user_id,
            'status'         => $normalizedStatus,
            'sub_status'     => $normalizedSubStatus,
            'message'        => $request->message ?? "Status diubah",
            'image_url'      => $imageUrl,
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Status laporan berhasil diperbarui.',
            'data'    => $this->formatReport($report->fresh(['user', 'checklistItems']), Auth::id()),
        ]);
    }

    public function logs(string $id)
    {
        $report = InspectionReport::findOrFail($id);
        $logs = $report->logs()->with(['user', 'taggedUser'])->get();

        return response()->json([
            'status' => 'success',
            'data'   => $logs->map(fn($log) => [
                'id'          => $log->id,
                'status'      => $log->status,
                'sub_status'  => $log->sub_status,
                'message'     => $log->message,
                'image_url'   => $log->image_url,
                'user_name'   => $log->user->full_name ?? 'System',
                'tagged_user' => $log->taggedUser ? $log->taggedUser->only(['id', 'full_name', 'role']) : null,
                'created_at'  => $log->created_at->format('Y-m-d H:i:s'),
                'date_human'  => $log->created_at->format('d M Y, H:i'),
            ])
        ]);
    }

    private function formatReport(InspectionReport $report, ?string $userId): array
    {
        return [
            'id'              => $report->id,
            'ticket_number'   => $report->ticket_number,
            'type'            => 'inspection',
            'title'           => $report->title,
            'description'     => $report->description,
            'status'          => $report->status,
            'sub_status'      => $report->sub_status,
            'location'        => $report->location,
            'image_url'       => $report->image_url,
            'is_read'         => $userId ? $report->isReadBy($userId) : false,
            'reported_by'     => $report->user ? $report->user->only(['id', 'full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'      => $report->created_at,
            'time_ago'        => $report->created_at?->diffForHumans(),
            'company'         => $report->company,
            'area'            => $report->area,
            'name_inspector'  => $report->name_inspector,
            'result'          => $report->result,
            'notes'           => $report->notes,
            'checklist_items' => $report->checklistItems->map(fn($item) => $item->only(['id', 'label', 'is_checked', 'sort_order'])),
        ];
    }
}