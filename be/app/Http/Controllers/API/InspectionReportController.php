<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\API\Concerns\BackfillsReportLogs;
use App\Http\Controllers\Controller;
use App\Models\ChecklistItem;
use App\Models\InspectionReport;
use App\Models\ReadStatus;
use App\Models\ReportLog;
use App\Models\ReportLogReply;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class InspectionReportController extends Controller
{
    use BackfillsReportLogs;

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
            // Supabase Storage URL (uploaded by client). Legacy `image` (file)
            // is still accepted as a fallback for older app builds.
            'image_url'           => 'nullable|url|max:500',
            'image_urls'          => 'nullable|array|max:10',
            'image_urls.*'        => 'url|max:500',
            'image'               => 'nullable|image|max:4096',
            'company'             => 'nullable|string|max:150',
            'area'                => 'nullable|string|max:100',
            'inspector'           => 'nullable|string|max:150',
            'reported_department' => 'nullable|string|max:100',
            'result'              => 'nullable|in:compliant,non_compliant,needs_follow_up',
            'notes'               => 'nullable|string',
            'checklist_items'     => 'nullable',
        ]);

        // Prefer the Supabase URLs the client uploaded directly. Fall back to
        // multipart file upload (legacy path) only if no URL was provided.
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

        $report = InspectionReport::create([
            'user_id'             => Auth::id(),
            'title'               => $request->title,
            'description'         => $request->description,
            'status'              => 'pending',
            'sub_status'          => 'validating',
            'location'            => $request->location,
            'image_url'           => $imageUrl,
            'image_urls'          => empty($imageUrls) ? null : $imageUrls,
            'company'             => $request->company ? strtoupper(trim($request->company)) : null,
            'area'                => $request->area,
            'name_inspector'      => $request->inspector,
            'reported_department' => $request->reported_department,
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
            'status'              => 'required|in:open,in_progress,closed,rejected',
            'sub_status'          => 'nullable|string|max:50',
            'message'             => 'nullable|string',
            // Supabase URL preferred; legacy file upload still accepted.
            'image_url'           => 'nullable|url|max:500',
            'image_urls'          => 'nullable|array|max:10',
            'image_urls.*'        => 'url|max:500',
            'image'               => 'nullable|image|max:8192',
            'tagged_user_id'      => 'nullable|uuid|exists:users,id',
            'reported_department' => 'nullable|string|max:100',
        ]);

        $report = InspectionReport::findOrFail($id);
        $user = Auth::user();

        // Superadmin = platform-level, full bypass regardless of tagging.
        // Admin = role-level update authority ONLY if also tagged (dept or name).
        // Reporter and assigned Inspector can also update (with the non-admin restrictions below).
        // Inspector = name tagged in name_inspector OR user's department tagged in reported_department.
        $isInspector = ($report->name_inspector && stripos($report->name_inspector, $user->full_name) !== false)
                    || (!empty($user->department) && $report->reported_department
                        && stripos($report->reported_department, $user->department) !== false);
        $isSuperadmin = $user->role === 'superadmin';
        $isAdmin = $user->role === 'admin' && $isInspector;
        $isReporter = $report->user_id === $user->id;

        if (!$isSuperadmin && !$isAdmin && !$isReporter && !$isInspector) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak. Anda tidak memiliki izin.'], 403);
        }

        $requestedStatus = $request->status;
        $normalizedStatus = $requestedStatus === 'rejected' ? 'closed' : $requestedStatus;
        $normalizedSubStatus = $request->sub_status;
        if ($requestedStatus === 'rejected' && !$normalizedSubStatus) {
            $normalizedSubStatus = 'rejected';
        }

        // Additional restrictions for non-admins (admins-of-tagged-dept and superadmin keep full powers)
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

        // Normalize multi-image URLs (Supabase URLs uploaded by client).
        $imageUrls = $request->input('image_urls', []);
        if (!is_array($imageUrls)) $imageUrls = [];
        // Sanitize: filter empty/non-strings, normalize to array, deduplicate
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

        // Debug log for multi-photo tracking
        \Illuminate\Support\Facades\Log::debug('updateStatus image_urls count: ' . count($imageUrls), [
            'report_id' => $id,
            'has_image_url' => !empty($imageUrl),
            'image_urls_sample' => array_slice($imageUrls, 0, 3),
        ]);

        // Linear timeline guard: reject backward moves and skips for non-superadmin.
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
        if ($request->has('reported_department')) {
            $updateData['reported_department'] = $request->reported_department;
        }

        DB::transaction(function () use ($report, $updateData, $normalizedStatus, $normalizedSubStatus, $request, $imageUrl, $imageUrls) {
            $this->backfillSkippedSubStatusLogs($report, $normalizedSubStatus, $request->tagged_user_id);

            $report->update($updateData);

            $report->logs()->create([
                'user_id'        => Auth::id(),
                'tagged_user_id' => $request->tagged_user_id,
                'status'         => $normalizedStatus,
                'sub_status'     => $normalizedSubStatus,
                'message'        => $request->message ?? "Status diubah",
                'image_url'      => $imageUrl,
                'image_urls'     => empty($imageUrls) ? null : $imageUrls,
            ]);
        });

        return response()->json([
            'status'  => 'success',
            'message' => 'Status laporan berhasil diperbarui.',
            'data'    => $this->formatReport($report->fresh(['user', 'checklistItems']), Auth::id()),
        ]);
    }

    public function logs(string $id)
    {
        $report = InspectionReport::findOrFail($id);
        $logs = $report->logs()
            ->with(['user', 'taggedUser'])
            ->withCount('replies')
            ->withMax('replies', 'created_at')
            ->get();
        $assignmentName = collect([
            $report->reported_department,
            $report->name_inspector,
        ])->filter(fn($value) => !empty(trim((string) $value)))->implode(', ');

        return response()->json([
            'status' => 'success',
            'data'   => $logs->map(function ($log) use ($assignmentName) {
                $userName = $log->user->full_name
                    ?? ($log->sub_status === 'assigned'
                        ? ($log->taggedUser->full_name ?? $assignmentName)
                        : 'System');

                $logImageUrls = $log->image_urls;
                if (empty($logImageUrls)) {
                    $logImageUrls = $log->image_url ? [$log->image_url] : [];
                }

                return [
                    'id'          => $log->id,
                    'status'      => $log->status,
                    'sub_status'  => $log->sub_status,
                    'message'     => $log->message,
                    'image_url'   => $log->image_url,
                    'image_urls'  => $logImageUrls,
                    'user_name'   => $userName,
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
        $report = InspectionReport::findOrFail($id);
        if (!$this->canAccessReportThread($report, Auth::user())) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
        }

        $log = $report->logs()->whereKey($logId)->firstOrFail();
        $replies = $log->replies()->with('user')->orderBy('created_at')->get();

        return response()->json([
            'status' => 'success',
            'data' => $replies->map(fn($reply) => [
                'id' => $reply->id,
                'report_log_id' => $reply->report_log_id,
                'parent_reply_id' => $reply->parent_reply_id,
                'user_name' => $reply->user->full_name ?? 'Unknown User',
                'user_role' => optional($reply->user)->role,
                'message' => $reply->message,
                'attachment_url' => $reply->attachment_url,
                'attachment_urls' => !empty($reply->attachment_urls)
                    ? $reply->attachment_urls
                    : ($reply->attachment_url ? [$reply->attachment_url] : []),
                'created_at' => $reply->created_at->format('Y-m-d H:i:s'),
                'date_human' => $reply->created_at->format('d M Y, H:i'),
            ]),
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

        $report = InspectionReport::findOrFail($id);
        $user = Auth::user();
        if (!$this->canAccessReportThread($report, $user)) {
            return response()->json(['status' => 'error', 'message' => 'Akses ditolak.'], 403);
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

        return response()->json([
            'status' => 'success',
            'message' => 'Balasan berhasil dikirim.',
            'data' => [
                'id' => $reply->id,
                'report_log_id' => $reply->report_log_id,
                'parent_reply_id' => $reply->parent_reply_id,
                'user_name' => $reply->user->full_name ?? 'Unknown User',
                'user_role' => optional($reply->user)->role,
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

    private function canAccessReportThread(InspectionReport $report, User $user): bool
    {
        if (in_array($user->role, ['admin', 'superadmin'])) return true;

        if ($report->user_id === $user->id) return true;

        $isAssignee = ($report->name_inspector && stripos($report->name_inspector, $user->full_name) !== false)
            || (!empty($user->department) && $report->reported_department
                && stripos($report->reported_department, $user->department) !== false);
        if ($isAssignee) return true;

        return ReportLog::query()
            ->where('reportable_type', InspectionReport::class)
            ->where('reportable_id', $report->id)
            ->where('user_id', $user->id)
            ->exists();
    }

    private function buildAssignmentTagMessage(InspectionReport $report, Request $request): ?string
    {
        $targets = collect();

        if ($request->filled('tagged_user_id')) {
            $taggedUser = User::find($request->tagged_user_id);
            if ($taggedUser && trim((string) $taggedUser->full_name) !== '') {
                $targets->push(trim($taggedUser->full_name));
            }
        }

        foreach ([$report->reported_department, $report->name_inspector] as $field) {
            if (empty($field)) {
                continue;
            }

            foreach (preg_split('/[,;]+/', (string) $field) ?: [] as $value) {
                $value = trim($value);
                if ($value !== '') {
                    $targets->push($value);
                }
            }
        }

        $targets = $targets->filter()->unique()->values();
        if ($targets->isEmpty()) {
            return null;
        }

        return 'TAG: ' . $targets->implode(', ');
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
            'image_urls'      => $report->image_urls ?? [],
            'is_read'         => $userId ? $report->isReadBy($userId) : false,
            'reported_by'     => $report->user ? $report->user->only(['id', 'full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'      => $report->created_at,
            'time_ago'        => $report->created_at?->diffForHumans(),
            'company'         => $report->company,
            'area'                => $report->area,
            'name_inspector'      => $report->name_inspector,
            'reported_department' => $report->reported_department,
            'result'              => $report->result,
            'notes'           => $report->notes,
            'checklist_items' => $report->checklistItems->map(fn($item) => $item->only(['id', 'label', 'is_checked', 'sort_order'])),
        ];
    }
}
