<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\HazardReport;
use App\Models\ReadStatus;
use App\Models\ReportLog;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class HazardReportController extends Controller
{
    protected $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    public function index(Request $request)
    {
        $query  = HazardReport::with(['user'])->latest();
        $user   = Auth::user();
        $userId = $user->id;

        // Apply privacy filter: private reports are visible only to the creator, the targeted PJA, or admins
        if (!in_array($user->role, ['admin', 'superadmin'])) {
            $query->where(function ($q) use ($user) {
                $q->where('is_public', true)
                ->orWhere('user_id', $user->id)
                ->orWhere('pic_department', 'like', '%' . $user->full_name . '%');
            });
        }

        if ($request->filled('severity'))   $query->where('severity', $request->severity);
        if ($request->filled('status'))     $query->where('status', $request->status);
        if ($request->filled('department')) $query->where('reported_department', $request->department);

        if ($request->filled('search')) {
            $s = $request->search;
            $query->where(fn($q) => $q
                ->where('title', 'like', "%{$s}%")
                ->orWhere('description', 'like', "%{$s}%")
                ->orWhere('location', 'like', "%{$s}%")
                ->orWhere('pic_department', 'like', "%{$s}%")
                ->orWhere('pelaku_pelanggaran', 'like', "%{$s}%")
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
            'severity'            => 'required|in:low,medium,high',
            'pic_department'      => 'nullable|string|max:100',
            'reported_department' => 'nullable|string|max:100',
            'hazard_category'     => 'nullable|in:TTA,KTA',
            'hazard_subcategory'  => 'nullable|string|max:150',
            'suggestion'          => 'nullable|string',
            'pelaku_pelanggaran'  => 'nullable|string|max:100',
            'pelapor_location'    => 'nullable|string|max:200',
            'kejadian_location'   => 'nullable|string|max:200',
            'isPublic'            => 'nullable|string',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('reports', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $report = HazardReport::create([
            'user_id'             => Auth::id(),
            'title'               => $request->title,
            'description'         => $request->description,
            'status'              => 'open',
            'location'            => $request->location,
            'pelapor_location'    => $request->pelapor_location,
            'kejadian_location'   => $request->kejadian_location,
            'image_url'           => $imageUrl,
            'severity'            => $request->severity,
            'pic_department'      => $request->pic_department,
            'pelaku_pelanggaran'  => $request->pelaku_pelanggaran,
            'reported_department' => $request->reported_department,
            'hazard_category'     => $request->hazard_category,
            'hazard_subcategory'  => $request->hazard_subcategory,
            'suggestion'          => $request->suggestion,
            'is_public'           => filter_var($request->input('isPublic', true), FILTER_VALIDATE_BOOLEAN),            
        ]);

        $report->logs()->create([
            'user_id' => Auth::id(),
            'status'  => 'open',
            'message' => 'Laporan hazard baru dibuat.',
        ]);

        $report->load('user');

        try {
            $admins = User::whereIn('role', ['admin', 'superadmin'])->get();
            $creatorName = $report->user->full_name ?? 'User';
            foreach ($admins as $admin) {
                /** @var \App\Models\User $admin */
                $this->notificationService->createNotification(
                    $admin, 'hazard', "Laporan Hazard Baru",
                    "$creatorName telah mengirim laporan: {$report->title}",
                    ['report_id' => $report->id, 'type' => 'hazard']
                );
            }
        } catch (\Exception $e) {}

        return response()->json([
            'status'  => 'success',
            'message' => 'Laporan hazard berhasil dikirim.',
            'data'    => $this->formatReport($report, Auth::id()),
        ], 201);
    }

    public function show(string $id)
    {
        $userId = Auth::id();
        $report = HazardReport::with('user')->findOrFail($id);

        ReadStatus::firstOrCreate([
            'user_id'   => $userId,
            'item_id'   => $report->id,
            'item_type' => 'hazard_report',
        ], ['read_at' => now()]);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatReport($report, $userId),
        ]);
    }

    public function destroy(string $id)
    {
        $report = HazardReport::findOrFail($id);
        $user = Auth::user();

        if ($report->user_id !== $user->id && !in_array($user->role, ['admin', 'superadmin'])) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
        }
        $report->delete();
        return response()->json(['status' => 'success', 'message' => 'Laporan berhasil dihapus.']);
    }

    public function updateStatus(Request $request, string $id)
    {
        $request->validate([
            'status'              => 'required|in:open,in_progress,closed',
            'sub_status'          => 'nullable|string|max:50',
            'message'             => 'nullable|string',
            'image'               => 'nullable|image|max:8192',
            'tagged_user_id'      => 'nullable|uuid|exists:users,id',
            'pic_department'      => 'nullable|string|max:100',
            'reported_department' => 'nullable|string|max:100',
        ]);

        if ($request->sub_status === 'reviewing' && !$request->hasFile('image')) {
            return response()->json(['status' => 'error', 'message' => 'Lampiran wajib.'], 422);
        }

        $report = HazardReport::findOrFail($id);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('report_logs', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $updateData = [
            'status'     => $request->status,
            'sub_status' => $request->sub_status,
        ];

        if ($request->has('pic_department'))      $updateData['pic_department'] = $request->pic_department;
        if ($request->has('reported_department')) $updateData['reported_department'] = $request->reported_department;

        $report->update($updateData);

        $report->logs()->create([
            'user_id'        => Auth::id(),
            'tagged_user_id' => $request->tagged_user_id,
            'status'         => $request->status,
            'sub_status'     => $request->sub_status,
            'message'        => $request->message ?? "Status diubah",
            'image_url'      => $imageUrl,
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Status laporan berhasil diperbarui.',
            'data'    => $this->formatReport($report->fresh('user'), Auth::id()),
        ]);
    }

    public function logs(string $id)
    {
        $report = HazardReport::findOrFail($id);
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

    private function formatReport(HazardReport $report, ?string $userId): array
    {
        return [
            'id'                  => $report->id,
            'ticket_number'       => $report->ticket_number,
            'title'               => $report->title,
            'description'         => $report->description,
            'status'              => $report->status,
            'sub_status'          => $report->sub_status,
            'location'            => $report->location,
            'pelapor_location'    => $report->pelapor_location,
            'kejadian_location'   => $report->kejadian_location,
            'image_url'           => $report->image_url,
            'is_read'             => $userId ? $report->isReadBy($userId) : false,
            'reported_by'         => $report->user ? $report->user->only(['id', 'full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'          => $report->created_at,
            'time_ago'            => $report->created_at?->diffForHumans(),
            'severity'            => $report->severity,
            'pic_department'      => $report->pic_department,
            'pelaku_pelanggaran'  => $report->pelaku_pelanggaran,
            'reported_department' => $report->reported_department,
            'hazard_category'     => $report->hazard_category,
            'hazard_subcategory'  => $report->hazard_subcategory,
            'suggestion'          => $report->suggestion,
            'is_public'           => (bool)$report->is_public,
            'due_date'            => $report->due_date,
            'sisa_hari'           => $report->due_date ? (now()->diffInDays($report->due_date, false)) : null,
        ];
    }
}