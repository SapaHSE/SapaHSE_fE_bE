<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\API\Concerns\BackfillsReportLogs;
use App\Http\Controllers\API\Concerns\ResolvesReportNotificationRecipients;
use App\Http\Controllers\Controller;
use App\Models\HazardCategory;
use App\Models\HazardReport;
use App\Models\ReadStatus;
use App\Models\ReportLog;
use App\Models\ReportLogReply;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class HazardReportController extends Controller
{
    use BackfillsReportLogs;
    use ResolvesReportNotificationRecipients;

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

        // Apply privacy filter: validating reports are private to creator/admin queue.
        if (!in_array($user->role, ['admin', 'superadmin'])) {
            $query->where(function ($q) use ($user) {
                $q->where(function ($sq) {
                    $sq->where('is_public', true)
                       ->where(function ($v) {
                           $v->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
                       });
                })
                ->orWhere('user_id', $user->id) // Creator can see their own reports (including validating)
                ->orWhere(function ($sq) use ($user) {
                    $sq->where('pic_department', 'like', '%' . $user->full_name . '%')
                       ->where(function ($v) {
                           $v->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
                       });
                });
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
            'image_url'           => 'nullable|url|max:2048',
            'image_urls'          => 'nullable|array|max:10',
            'image_urls.*'        => 'url|max:2048',
            'image'               => 'nullable|image|max:4096',
            'severity'            => 'required|in:low,medium,high',
            'pic_department'      => 'nullable|string|max:100',
            'company'             => 'nullable|string|max:150',
            'area'                => 'nullable|string|max:200',
            'reported_department' => 'nullable|string|max:100',
            'hazard_category'     => 'nullable|string|max:50',
            'hazard_subcategory'  => 'nullable|string|max:150',
            'suggestion'          => 'nullable|string',
            'pelaku_pelanggaran'  => 'nullable|string|max:100',
            'pelapor_location'    => 'nullable|string|max:200',
            'kejadian_location'   => 'nullable|string|max:200',
            'isPublic'            => 'nullable|string',
        ]);

        // Prefer the Supabase URLs the client uploaded directly. Fall back to
        // multipart file upload (legacy path) only if no URL was provided.
        $imageUrls = $request->input('image_urls', []);
        if (!is_array($imageUrls)) $imageUrls = [];
        $imageUrls = array_values(
            array_filter(
                array_unique(array_map('strval', $imageUrls)),
                fn($u) => is_string($u)
                    && $u !== ''
                    && filter_var($u, FILTER_VALIDATE_URL) !== false
            )
        );

        $imageUrl = $request->input('image_url');
        if (!$imageUrl && !empty($imageUrls)) {
            $imageUrl = $imageUrls[0];
        }
        if (!$imageUrl && $request->hasFile('image')) {
            $path = $request->file('image')->store('reports', 'public');
            $imageUrl = asset('storage/' . $path);
            $imageUrls = [$imageUrl];
        }
        if (empty($imageUrls) && $imageUrl) {
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

        $normalizedHazardCategory = $this->normalizeHazardCategoryCodes($request->hazard_category);
        $normalizedHazardSubcategory = $this->normalizeHazardSubcategories($request->hazard_subcategory);
        $kejadianLocation = trim((string) $request->input('kejadian_location', ''));
        if ($kejadianLocation === '') {
            $kejadianLocation = '-';
        }

        $report = HazardReport::create([
            'user_id'             => Auth::id(),
            'title'               => $request->title,
            'description'         => $request->description,
            'status'              => 'open',
            'sub_status'          => 'validating',
            'location'            => $request->location,
            'pelapor_location'    => $request->pelapor_location,
            'kejadian_location'   => $kejadianLocation,
            'image_url'           => $imageUrl,
            'image_urls'          => !empty($imageUrls) ? $imageUrls : null,
            'severity'            => $request->severity,
            'pic_department'      => $picDepartment,
            'pelaku_pelanggaran'  => $request->pelaku_pelanggaran,
            'company'             => $request->company,
            'area'                => $request->area,
            'reported_department' => $request->reported_department,
            'hazard_category'     => $normalizedHazardCategory,
            'hazard_subcategory'  => $normalizedHazardSubcategory,
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
            'status'              => 'required|in:open,in_progress,closed,rejected',
            'sub_status'          => 'nullable|string|max:50',
            'message'            => 'nullable|string',
            'image_url'          => 'nullable|url|max:500',
            'image_urls'         => 'nullable|array|max:10',
            'image_urls.*'       => 'url|max:500',
            'image'              => 'nullable|image|max:8192',
            'tagged_user_id'     => 'nullable|uuid|exists:users,id',
            'pic_department'     => 'nullable|string|max:100',
            'reported_department' => 'nullable|string|max:100',
        ]);

        $report = HazardReport::findOrFail($id);
        $user = Auth::user();

        // Suspect/reported users are never allowed to update the hazard,
        // even when they also have admin or superadmin roles.
        $isReportedUser = $this->csvContainsToken($report->pelaku_pelanggaran, $user->full_name);
        if ($isReportedUser) {
            return response()->json([
                'status' => 'error',
                'message' => 'Akses ditolak. User terlapor tidak dapat memperbarui status laporan.',
            ], 403);
        }

        // Superadmin = platform-level, full bypass regardless of tagging.
        // Admin = role-level update authority for all hazard reports.
        // PJA = name tagged in pic_department OR user's department tagged in reported_department.
        $isPja = ($report->pic_department && stripos($report->pic_department, $user->full_name) !== false)
             || (!empty($user->department) && $report->reported_department
                 && stripos($report->reported_department, $user->department) !== false);
        $isSuperadmin = $user->role === 'superadmin';
        $isAdmin = $user->role === 'admin';
        $isApprovedOrLater = $report->sub_status === null
            ? in_array($report->status, ['in_progress', 'closed'], true)
            : $report->sub_status !== 'validating';
        $canPjaUpdate = $isPja && $isApprovedOrLater;

        if (!$isSuperadmin && !$isAdmin && !$canPjaUpdate) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak. Anda tidak memiliki izin.'], 403);
        }

        // Normalize multi-image URLs (Supabase URLs uploaded by client).
        $imageUrls = $request->input('image_urls', []);
        if (!is_array($imageUrls)) $imageUrls = [];
        $imageUrls = array_values(
            array_filter(
                array_unique(
                    array_map('strval', $imageUrls)
                ),
                fn($u) => is_string($u) && $u !== '' && filter_var($u, FILTER_VALIDATE_URL) !== false
            )
        );

        // Prefer client-supplied Supabase URL; fall back to legacy file upload.
        $imageUrl = $request->input('image_url');
        if (!$imageUrl && !empty($imageUrls)) {
            $imageUrl = $imageUrls[0];
        }
        if (!$imageUrl && $request->hasFile('image')) {
            $path = $request->file('image')->store('report_logs', 'public');
            $imageUrl = asset('storage/' . $path);
            $imageUrls = [$imageUrl];
        }
        if (empty($imageUrls) && $imageUrl) {
            $imageUrls = [$imageUrl];
        }

        $requestedStatus = $request->status;
        $normalizedStatus = $requestedStatus === 'rejected' ? 'closed' : $requestedStatus;
        $normalizedSubStatus = $request->sub_status;
        if ($requestedStatus === 'rejected' && !$normalizedSubStatus) {
            $normalizedSubStatus = 'rejected';
        }

        // Additional restrictions for non-admins (admins and superadmin keep full powers).
        if (!$isAdmin && !$isSuperadmin) {
            // Cannot select 'validating' or 'approved'
            if (in_array($normalizedSubStatus, ['validating', 'approved'])) {
                return response()->json(['status' => 'error', 'message' => 'Izin ditolak untuk status ini.'], 403);
            }
            // Cannot select final closed status (including explicit rejected request)
            if (in_array($requestedStatus, ['closed', 'rejected'])) {
                return response()->json(['status' => 'error', 'message' => 'Hanya Admin yang dapat menutup laporan.'], 403);
            }
        }

        if ($normalizedSubStatus === 'reviewing'
            && !$request->hasFile('image')
            && empty($imageUrl)
            && empty($imageUrls)) {
            return response()->json(['status' => 'error', 'message' => 'Lampiran wajib.'], 422);
        }

        // Linear timeline guard: reject backward moves and illegal skips for non-superadmin.
        if (!$isSuperadmin) {
            $progressionError = $this->assertLinearProgression(
                $report,
                $normalizedStatus,
                $normalizedSubStatus,
                $isAdmin
            );
            if ($progressionError !== null) {
                return response()->json([
                    'status'  => 'error',
                    'message' => $progressionError,
                ], 422);
            }
        }

        $updateData = [
            'status'     => $normalizedStatus,
            'sub_status' => $normalizedSubStatus,
        ];

        if ($request->has('pic_department'))      $updateData['pic_department'] = $request->pic_department;
        if ($request->has('reported_department')) $updateData['reported_department'] = $request->reported_department;

        return DB::transaction(function () use ($report, $updateData, $normalizedStatus, $normalizedSubStatus, $request, $imageUrl, $imageUrls) {
            $this->backfillSkippedSubStatusLogs($report, $normalizedSubStatus, $request->tagged_user_id);

            $report->update($updateData);

            $report->logs()->create([
                'user_id'        => Auth::id(),
                'tagged_user_id' => $request->tagged_user_id,
                'status'         => $normalizedStatus,
                'sub_status'     => $normalizedSubStatus,
                'message'        => $request->message ?? "Status diubah",
                'image_url'      => $imageUrl,
                'image_urls'     => !empty($imageUrls) ? json_encode($imageUrls) : null,
            ]);

            // Kirim notifikasi ke semua pihak terkait
            $statusText = $normalizedSubStatus ?: $normalizedStatus;
            $notifTitle = "Update Laporan Hazard";
            $notifBody = "Status laporan '{$report->title}' diperbarui menjadi: " . strtoupper($statusText);

            try {
                $recipients = $this->resolveReportNotificationRecipients(
                    $report,
                    HazardReport::class,
                    $request->tagged_user_id,
                    Auth::id(),
                    ['pic_department', 'pelaku_pelanggaran'],
                    ['reported_department']
                );

                foreach ($recipients as $recipient) {
                    $this->notificationService->createNotification(
                        $recipient,
                        'hazard_update',
                        $notifTitle,
                        $notifBody,
                        ['report_id' => $report->id, 'type' => 'hazard']
                    );
                }
            } catch (\Exception $e) {
                \Log::error('Gagal mengirim notifikasi update hazard ke pihak terkait: ' . $e->getMessage());
            }

            return response()->json([
                'status'  => 'success',
                'message' => 'Status laporan berhasil diperbarui.',
                'data'    => $this->formatReport($report->fresh('user'), Auth::id()),
            ]);
        });
    }

    public function logs(string $id)
    {
        $report = HazardReport::findOrFail($id);
        if (!$this->canAccessReportThread($report, Auth::user())) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
        }
        $logs = $report->logs()
            ->with(['user', 'taggedUser'])
            ->withCount('replies')
            ->withMax('replies', 'created_at')
            ->get();

        return response()->json([
            'status' => 'success',
            'data'   => $logs->map(function ($log) {
                $photoPath = optional($log->user)->profile_photo;
                $userPhotoUrl = null;
                if (!empty($photoPath)) {
                    $photoPath = (string) $photoPath;
                    $userPhotoUrl = str_starts_with($photoPath, 'http')
                        ? $photoPath
                        : asset('storage/' . ltrim($photoPath, '/'));
                }

                $logImageUrls = $log->image_urls;
                if (empty($logImageUrls)) {
                    $logImageUrls = $log->image_url ? [$log->image_url] : [];
                }

                return [
                    'id'          => $log->id,
                    'user_id'     => $log->user_id,
                    'status'      => $log->status,
                    'sub_status'  => $log->sub_status,
                    'message'     => $log->message,
                    'image_url'   => $log->image_url,
                    'image_urls'  => $logImageUrls,
                    'user_name'   => $log->user->full_name ?? 'System',
                    'user_photo_url' => $userPhotoUrl,
                    'tagged_user' => $log->taggedUser ? $log->taggedUser->only(['id', 'full_name', 'role']) : null,
                    'reply_count' => (int) ($log->replies_count ?? 0),
                    'latest_reply_at' => $log->replies_max_created_at
                        ? now()->parse((string) $log->replies_max_created_at)->format('Y-m-d H:i:s')
                        : null,
                    'created_at'  => $log->created_at->format('Y-m-d H:i:s'),
                    'date_human'  => $log->created_at->format('d M Y, H:i'),
                ];
            })
        ]);
    }

    public function logReplies(string $id, string $logId)
    {
        $report = HazardReport::findOrFail($id);
        if (!$this->canAccessReportThread($report, Auth::user())) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
        }

        $log = $report->logs()->whereKey($logId)->firstOrFail();
        $replies = $log->replies()->with('user')->orderBy('created_at')->get();

        return response()->json([
            'status' => 'success',
            'data' => $replies->map(function ($reply) {
                $photoPath = optional($reply->user)->profile_photo;
                $photoUrl = null;
                if (!empty($photoPath)) {
                    $photoPath = (string) $photoPath;
                    $photoUrl = str_starts_with($photoPath, 'http')
                        ? $photoPath
                        : asset('storage/' . ltrim($photoPath, '/'));
                }

                return [
                    'id' => $reply->id,
                    'report_log_id' => $reply->report_log_id,
                    'parent_reply_id' => $reply->parent_reply_id,
                    'user_name' => $reply->user->full_name ?? 'Unknown User',
                    'user_role' => optional($reply->user)->role,
                    'user_photo_url' => $photoUrl,
                    'message' => $reply->message,
                    'attachment_url' => $reply->attachment_url,
                    'attachment_urls' => !empty($reply->attachment_urls)
                        ? $reply->attachment_urls
                        : ($reply->attachment_url ? [$reply->attachment_url] : []),
                    'created_at' => $reply->created_at->format('Y-m-d H:i:s'),
                    'date_human' => $reply->created_at->format('d M Y, H:i'),
                ];
            }),
        ]);
    }

    public function createLogReply(Request $request, string $id, string $logId)
    {
        $request->validate([
            'message' => 'required|string|max:2000',
            'parent_reply_id' => 'nullable|uuid|exists:report_log_replies,id',
            'attachment_url' => 'nullable|url|max:500',
            'attachment_urls' => 'nullable|array|max:10',
            'attachment_urls.*' => 'url|max:500',
        ]);

        $report = HazardReport::findOrFail($id);
        $user = Auth::user();
        if (!$this->canAccessReportThread($report, $user)) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
        }
        if ($report->status === 'closed') {
            return response()->json([
                'status' => 'error',
                'message' => 'Laporan sudah ditutup. Balasan tidak diizinkan.',
            ], 422);
        }

        $attachmentUrls = $request->input('attachment_urls', []);
        if (!is_array($attachmentUrls)) $attachmentUrls = [];
        $attachmentUrls = array_values(array_filter($attachmentUrls, fn($u) => is_string($u) && $u !== ''));
        $attachmentUrl = $request->attachment_url ?: (!empty($attachmentUrls) ? $attachmentUrls[0] : null);

        $log = $report->logs()->whereKey($logId)->firstOrFail();

        $parentReplyId = $request->input('parent_reply_id');
        if ($parentReplyId) {
            $parent = ReportLogReply::find($parentReplyId);
            if (!$parent || $parent->report_log_id !== $log->id || $parent->parent_reply_id !== null) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Balasan hanya bisa dikirim ke balasan utama pada thread ini.',
                ], 422);
            }
        }

        $reply = ReportLogReply::create([
            'report_log_id' => $log->id,
            'parent_reply_id' => $parentReplyId,
            'user_id' => $user->id,
            'message' => trim((string) $request->message),
            'attachment_url' => $attachmentUrl,
            'attachment_urls' => empty($attachmentUrls) ? null : $attachmentUrls,
        ]);
        $reply->load('user');

        // Kirim notifikasi ke pihak terkait
        try {
            // 1. Notif ke reporter (jika bukan reporter yang balas)
            if ($report->user_id !== $user->id) {
                $this->notificationService->createNotification(
                    $report->user,
                    'hazard_reply',
                    "Komentar Baru di Laporan Hazard",
                    "{$user->full_name} membalas laporan '{$report->title}'",
                    ['report_id' => $report->id, 'type' => 'hazard', 'log_id' => $log->id]
                );
            }
            
            // 2. Notif ke pembuat log (jika bukan pembuat log dan bukan reporter)
            if ($log->user_id !== $user->id && $log->user_id !== $report->user_id) {
                $this->notificationService->createNotification(
                    $log->user,
                    'hazard_reply',
                    "Komentar Baru di Log Laporan",
                    "{$user->full_name} membalas pesan Anda di laporan '{$report->title}'",
                    ['report_id' => $report->id, 'type' => 'hazard', 'log_id' => $log->id]
                );
            }
        } catch (\Exception $e) {
            \Log::error('Gagal mengirim notifikasi balasan hazard: ' . $e->getMessage());
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Balasan berhasil dikirim.',
            'data' => [
                'id' => $reply->id,
                'report_log_id' => $reply->report_log_id,
                'parent_reply_id' => $reply->parent_reply_id,
                'user_name' => $reply->user->full_name ?? 'Unknown User',
                'user_role' => optional($reply->user)->role,
                'user_photo_url' => optional($reply->user)->profile_photo
                    ? (str_starts_with((string) optional($reply->user)->profile_photo, 'http')
                        ? (string) optional($reply->user)->profile_photo
                        : asset('storage/' . ltrim((string) optional($reply->user)->profile_photo, '/')))
                    : null,
                'message' => $reply->message,
                'attachment_url' => $reply->attachment_url,
                'attachment_urls' => !empty($reply->attachment_urls)
                    ? $reply->attachment_urls
                    : ($reply->attachment_url ? [$reply->attachment_url] : []),
                'created_at' => $reply->created_at->format('Y-m-d H:i:s'),
                'date_human' => $reply->created_at->format('d M Y, H:i'),
            ],
        ], 201);
    }

    private function canAccessReportThread(HazardReport $report, User $user): bool
    {
        if (in_array($user->role, ['admin', 'superadmin'])) return true;

        if ($report->user_id === $user->id) return true;

        $isAssignee = ($report->pic_department && stripos($report->pic_department, $user->full_name) !== false)
            || $this->csvContainsToken($report->reported_department, $user->department);
        if ($isAssignee) return true;

        return ReportLog::query()
            ->where('reportable_type', HazardReport::class)
            ->where('reportable_id', $report->id)
            ->where('user_id', $user->id)
            ->exists();
    }

    private function formatReport(HazardReport $report, ?string $userId): array
    {
        [$categoryCodes, $categoryNames] = $this->resolveHazardCategories($report->hazard_category);
        $hazardSubcategories = $this->tokenizeCsvPreserveCase($report->hazard_subcategory);

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
            'image_urls'          => $report->image_urls
                ?? ($report->image_url ? [$report->image_url] : []),
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
            'hazard_category_codes' => $categoryCodes,
            'hazard_category_names' => $categoryNames,
            'hazard_subcategory'  => $report->hazard_subcategory,
            'hazard_subcategories' => $hazardSubcategories,
            'suggestion'          => $report->suggestion,
            'is_public'           => (bool)$report->is_public,
            'due_date'            => $report->due_date,
            'sisa_hari'           => $report->due_date ? (now()->diffInDays($report->due_date, false)) : null,
        ];
    }

    private function normalizeHazardCategoryCodes(?string $value): ?string
    {
        if ($value === null || trim($value) === '') return null;

        $tokens = preg_split('/[,;]+/', $value) ?: [];
        $codes = [];
        $seen = [];
        foreach ($tokens as $token) {
            $code = strtoupper(trim((string) $token));
            if ($code === '' || isset($seen[$code])) {
                continue;
            }
            $seen[$code] = true;
            $codes[] = $code;
        }

        return empty($codes) ? null : implode(',', $codes);
    }

    private function normalizeHazardSubcategories(?string $value): ?string
    {
        if ($value === null || trim($value) === '') return null;

        $tokens = preg_split('/[,;]+/', $value) ?: [];
        $names = [];
        $seen = [];
        foreach ($tokens as $token) {
            $name = trim((string) $token);
            $key = strtolower($name);
            if ($name === '' || isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $names[] = $name;
        }

        return empty($names) ? null : implode(', ', $names);
    }

    private function resolveHazardCategories(?string $value): array
    {
        $codes = $this->tokenizeCsvUpper($value);
        if (empty($codes)) {
            return [[], []];
        }

        $categoryMap = HazardCategory::query()
            ->whereIn('code', $codes)
            ->get(['code', 'name'])
            ->mapWithKeys(fn($c) => [strtoupper((string) $c->code) => (string) $c->name])
            ->all();

        $names = [];
        foreach ($codes as $code) {
            $names[] = $categoryMap[$code] ?? $code;
        }

        return [$codes, $names];
    }

    private function csvContainsToken(?string $csv, ?string $needle): bool
    {
        $needle = strtolower(trim((string) $needle));
        if ($needle === '') return false;

        return in_array($needle, $this->tokenizeCsv($csv), true);
    }

    private function tokenizeCsv(?string $value): array
    {
        if ($value === null || trim($value) === '') return [];

        return array_values(array_unique(array_filter(array_map(
            fn($token) => strtolower(trim((string) $token)),
            explode(',', $value)
        ))));
    }

    private function tokenizeCsvUpper(?string $value): array
    {
        if ($value === null || trim($value) === '') return [];

        $tokens = preg_split('/[,;]+/', $value) ?: [];
        $result = [];
        $seen = [];
        foreach ($tokens as $token) {
            $normalized = strtoupper(trim((string) $token));
            if ($normalized === '' || isset($seen[$normalized])) {
                continue;
            }
            $seen[$normalized] = true;
            $result[] = $normalized;
        }

        return $result;
    }

    private function tokenizeCsvPreserveCase(?string $value): array
    {
        if ($value === null || trim($value) === '') return [];

        $tokens = preg_split('/[,;]+/', $value) ?: [];
        $result = [];
        $seen = [];
        foreach ($tokens as $token) {
            $normalized = trim((string) $token);
            $key = strtolower($normalized);
            if ($normalized === '' || isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $result[] = $normalized;
        }

        return $result;
    }
}
