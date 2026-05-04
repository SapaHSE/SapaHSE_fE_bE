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

        // Apply visibility filter: while sub_status='validating', only the creator and admins can see.
        // After approval (sub_status != 'validating'), tagged PJA, Tersangka Pelanggaran, and public viewers may see.
        if (!in_array($user->role, ['admin', 'superadmin'])) {
            $notValidating = function ($sq) {
                $sq->where(function ($x) {
                    $x->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
                });
            };

            $query->where(function ($q) use ($user, $notValidating) {
                $q->where(function ($sq) use ($notValidating) {
                    $sq->where('is_public', true);
                    $notValidating($sq);
                })
                ->orWhere('user_id', $user->id) // Creator selalu lihat (termasuk validating)
                ->orWhere(function ($sq) use ($user, $notValidating) {
                    $sq->where('pic_department', 'like', '%' . $user->full_name . '%');
                    $notValidating($sq);
                })
                ->orWhere(function ($sq) use ($user, $notValidating) {
                    $sq->where('pelaku_pelanggaran', 'like', '%' . $user->full_name . '%');
                    $notValidating($sq);
                });
                if (!empty($user->department)) {
                    $q->orWhere(function ($sq) use ($user, $notValidating) {
                        $sq->where('reported_department', 'like', '%' . $user->department . '%');
                        $notValidating($sq);
                    });
                }
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
            // Supabase Storage URL (uploaded by client). Legacy `image` (file)
            // is still accepted as a fallback for older app builds.
            'image_url'           => 'nullable|url|max:500',
            'image_urls'          => 'nullable|array|max:10',
            'image_urls.*'        => 'url|max:500',
            'image'               => 'nullable|image|max:4096',
            'severity'            => 'required|in:low,medium,high',
            'pic_department'      => 'nullable|string|max:100',
            'company'             => 'nullable|string|max:150',
            'area'                => 'nullable|string|max:200',
            'reported_department' => 'nullable|string|max:100',
            'hazard_category'     => 'nullable|in:TTA,KTA',
            'hazard_subcategory'  => 'nullable|string|max:150',
            'suggestion'          => 'nullable|string',
            'pelaku_pelanggaran'  => 'nullable|string|max:100',
            'pelapor_location'    => 'nullable|string|max:200',
            'kejadian_location'   => 'nullable|string|max:200',
            'isPublic'            => 'nullable|string',
        ]);

        // Prefer the Supabase URLs the client uploaded directly. Fall back to
        // the multipart file upload (legacy path) only if no URL was provided.
        $imageUrls = $request->input('image_urls', []);
        if (!is_array($imageUrls)) $imageUrls = [];
        $imageUrls = array_values(array_filter($imageUrls, fn($u) => is_string($u) && $u !== ''));

        $imageUrl = $request->input('image_url');
        if (!$imageUrl && !empty($imageUrls)) {
            $imageUrl = $imageUrls[0];
        }
        if (!$imageUrl && $request->hasFile('image')) {
            $path = $request->file('image')->store('reports', 'public');
            $imageUrl = asset('storage/' . $path);
            $imageUrls = [$imageUrl];
        }

       // Auto-tag Departemen HSE
        $picDepartment = $request->pic_department;
        if (empty($picDepartment)) {
            $picDepartment = 'Departemen HSE';
        } else {
            // Append if not already there
            if (stripos($picDepartment, 'HSE') === false) {
                $picDepartment .= ', Departemen HSE';
            }
        }

        $report = HazardReport::create([
            'user_id'             => Auth::id(),
            'title'               => $request->title,
            'description'         => $request->description,
            'status'              => 'open',
            'sub_status'          => 'validating',
            'location'            => $request->location,
            'pelapor_location'    => $request->pelapor_location,
            'kejadian_location'   => $request->kejadian_location,
            'image_url'           => $imageUrl,
            'image_urls'          => empty($imageUrls) ? null : $imageUrls,
            'severity'            => $request->severity,
            'pic_department'      => $request->pic_department,
            'pelaku_pelanggaran'  => $request->pelaku_pelanggaran,
            'company'             => $request->company,
            'area'                => $request->area,
            'reported_department' => $request->reported_department,
            'hazard_category'     => $request->hazard_category,
            'hazard_subcategory'  => $request->hazard_subcategory,
            'suggestion'          => $request->suggestion,
            'is_public'           => filter_var($request->input('isPublic', true), FILTER_VALIDATE_BOOLEAN),            
        ]);

        $report->logs()->create([
            'user_id'    => Auth::id(),
            'status'     => 'open',
            'sub_status' => 'validating',
            'message'    => 'Laporan hazard baru dibuat dan sedang dalam proses validasi admin.',
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
            'status'              => 'required|in:pending,open,in_progress,closed,rejected',
            'sub_status'          => 'nullable|string|max:50',
            'message'             => 'nullable|string',
            // Supabase URL preferred; legacy file upload still accepted.
            'image_url'           => 'nullable|url|max:500',
            'image'               => 'nullable|image|max:8192',
            'tagged_user_id'      => 'nullable|uuid|exists:users,id',
            'pic_department'      => 'nullable|string|max:100',
            'reported_department' => 'nullable|string|max:100',
        ]);

        $report = HazardReport::findOrFail($id);
        $user = Auth::user();

        // Admin and Superadmin both have full update authority regardless of tagging.
        // Reporter and tagged PJA can also update (with the non-admin restrictions below).
        // PJA = name tagged in pic_department OR user's department tagged in reported_department.
        $isPja = ($report->pic_department && stripos($report->pic_department, $user->full_name) !== false)
              || (!empty($user->department) && $report->reported_department
                  && stripos($report->reported_department, $user->department) !== false);
        $isAdmin = in_array($user->role, ['admin', 'superadmin']);
        $isReporter = $report->user_id === $user->id;

        if (!$isAdmin && !$isReporter && !$isPja) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak. Anda tidak memiliki izin.'], 403);
        }

        $requestedStatus = $request->status;
        $normalizedStatus = $requestedStatus === 'rejected' ? 'closed' : $requestedStatus;
        $normalizedSubStatus = $request->sub_status;
        if ($requestedStatus === 'rejected' && !$normalizedSubStatus) {
            $normalizedSubStatus = 'rejected';
        }

        // ========== NEW: STATE MACHINE VALIDATION ==========
        $validationResult = \App\Services\ReportStatusValidator::validateTransition(
            $report,
            $normalizedStatus,
            $normalizedSubStatus,
            $isAdmin
        );

        if (!$validationResult['valid']) {
            return response()->json([
                'status' => 'error',
                'message' => $validationResult['error'],
                'current_state' => [
                    'status' => $report->status,
                    'sub_status' => $report->sub_status,
                ],
                'suggestion' => \App\Services\ReportStatusValidator::getNextStepSuggestion($report),
            ], 422);
        }
        // ========== END STATE MACHINE VALIDATION ==========

        // Additional restrictions for non-admins (kept for compatibility)
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

        $hasAttachment = $request->filled('image_url') || $request->hasFile('image');
        if ($normalizedSubStatus === 'reviewing' && !$hasAttachment) {
            return response()->json(['status' => 'error', 'message' => 'Lampiran wajib. Bukti foto harus dilampirkan untuk tahap verifikasi.'], 422);
        }

        // Prefer client-supplied Supabase URL; fall back to legacy file upload.
        $imageUrl = $request->input('image_url');
        if (!$imageUrl && $request->hasFile('image')) {
            $path = $request->file('image')->store('report_logs', 'public');
            $imageUrl = asset('storage/' . $path);
        }

        $updateData = [
            'status'     => $normalizedStatus,
            'sub_status' => $normalizedSubStatus,
        ];

        if ($request->has('pic_department'))      $updateData['pic_department'] = $request->pic_department;
        if ($request->has('reported_department')) $updateData['reported_department'] = $request->reported_department;

        $report->update($updateData);

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
        $dueDate  = $report->due_date; // Carbon|null (cast on model)
        $now      = now();
        $sisaHari = $dueDate
            ? (int) $now->diffInDays($dueDate, false)
            : null;

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
            'image_urls'          => $report->image_urls ?? [],
            'is_read'             => $userId ? $report->isReadBy($userId) : false,
            'reported_by'         => $report->user ? $report->user->only(['id', 'full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'          => $report->created_at,
            'time_ago'            => $report->created_at?->diffForHumans(),
            'severity'            => $report->severity,
            'pic_department'      => $report->pic_department,
            'pelaku_pelanggaran'  => $report->pelaku_pelanggaran,
            'company'             => $report->company,
            'area'                => $report->area,
            'reported_department' => $report->reported_department,
            'hazard_category'     => $report->hazard_category,
            'hazard_subcategory'  => $report->hazard_subcategory,
            'suggestion'          => $report->suggestion,
            'is_public'           => (bool)$report->is_public,
            'due_date'            => $dueDate?->toDateTimeString(),
            'due_date_human'      => $dueDate?->translatedFormat('d M Y'),
            'sisa_hari'           => $sisaHari,
            'is_overdue'          => $dueDate !== null && $dueDate->isPast(),
        ];
    }
}