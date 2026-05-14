<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\HazardCategory;
use App\Models\ReadStatus;
use App\Models\HazardReport;
use App\Models\InspectionReport;
use App\Models\User;
use App\Models\UserCertification;
use App\Models\UserLicense;
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

        $readAnnouncementIds = ReadStatus::where('user_id', $userId)
            ->where('item_type', 'announcement')
            ->pluck('item_id');

        // Admin / Superadmin melihat queue validating.
        $isAdminOrSA = in_array($user->role, ['admin', 'superadmin'], true);
        $isSuper = $user->role === 'superadmin';

        $readApprovalRegistrationIds = collect();
        $readApprovalLicenseIds = collect();
        $readApprovalCertificationIds = collect();

        if ($isSuper) {
            $readApprovalRegistrationIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_registration')
                ->pluck('item_id');
            $readApprovalLicenseIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_license')
                ->pluck('item_id');
            $readApprovalCertificationIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_certification')
                ->pluck('item_id');
        }

        // Personal: reports where user is PJA, Tersangka Pelanggaran, Inspector, or tagged.
        $personalHazardUnread = HazardReport::where(function ($q) use ($user, $isAdminOrSA) {
                $q->where(function ($qq) use ($user) {
                    $qq->where(function ($pj) use ($user) {
                        $pj->where('pic_department', 'like', '%' . $user->full_name . '%')
                           ->orWhere('pelaku_pelanggaran', 'like', '%' . $user->full_name . '%');
                        if (!empty($user->department)) {
                            $pj->orWhere('reported_department', 'like', '%' . $user->department . '%');
                        }
                    })->where(function ($v) {
                        $v->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
                    });
                });
                if ($isAdminOrSA) {
                    $q->orWhere('sub_status', 'validating');
                }
            })
            ->whereNotIn('id', $readHazardIds)
            ->count();

        $personalInspectionUnread = InspectionReport::where(function ($q) use ($user) {
                $q->where('name_inspector', $user->full_name);
                if (!empty($user->department)) {
                    $q->orWhere('reported_department', 'like', '%' . $user->department . '%');
                }
            })
            ->where(function ($v) {
                $v->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
            })
            ->whereNotIn('id', $readInspectionIds)
            ->count();

        $unreadAnnouncementsCount = Announcement::active()
            ->whereNotIn('id', $readAnnouncementIds)
            ->count();

        $pendingRegistrationUnread = 0;
        $pendingLicenseUnread = 0;
        $pendingCertificationUnread = 0;
        if ($isSuper) {
            $pendingRegistrationUnread = User::where('registration_status', 'pending')
                ->whereNotIn('id', $readApprovalRegistrationIds)
                ->count();
            $pendingLicenseUnread = UserLicense::where('approval_status', 'pending')
                ->whereNotIn('id', $readApprovalLicenseIds)
                ->count();
            $pendingCertificationUnread = UserCertification::where('approval_status', 'pending')
                ->whereNotIn('id', $readApprovalCertificationIds)
                ->count();
        }
        $approvalUnreadCount = $pendingRegistrationUnread + $pendingLicenseUnread + $pendingCertificationUnread;

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
            $hQuery = HazardReport::with(['user'])
                ->where(function ($q) use ($user, $isAdminOrSA) {
                    $q->where(function ($qq) use ($user) {
                        $qq->where(function ($pj) use ($user) {
                            $pj->where('pic_department', 'like', '%' . $user->full_name . '%')
                               ->orWhere('pelaku_pelanggaran', 'like', '%' . $user->full_name . '%');
                            if (!empty($user->department)) {
                                $pj->orWhere('reported_department', 'like', '%' . $user->department . '%');
                            }
                        })->where(function ($v) {
                            $v->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
                        });
                    });
                    if ($isAdminOrSA) {
                        $q->orWhere('sub_status', 'validating');
                    }
                });
            $iQuery = InspectionReport::with(['user', 'checklistItems'])
                ->where(function ($q) use ($user) {
                    $q->where('name_inspector', $user->full_name);
                    if (!empty($user->department)) {
                        $q->orWhere('reported_department', 'like', '%' . $user->department . '%');
                    }
                })
                ->where(function ($v) {
                    $v->whereNull('sub_status')->orWhere('sub_status', '!=', 'validating');
                });

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

            $hazards = $hQuery->get()->map(function (HazardReport $r) use ($userId) {
                return $this->formatHazard($r, $userId);
            });
            $inspections = $iQuery->get()->map(function (InspectionReport $r) use ($userId) {
                return $this->formatInspection($r, $userId);
            });

            $approvalItems = collect();
            if ($isSuper) {
                $approvalItems = $this->pendingRegistrationItems($readApprovalRegistrationIds)
                    ->concat($this->pendingLicenseItems($readApprovalLicenseIds))
                    ->concat($this->pendingCertificationItems($readApprovalCertificationIds));

                if ($isRead !== null) {
                    $approvalItems = $approvalItems
                        ->filter(fn(array $item) => (bool) $item['is_read'] === $isRead)
                        ->values();
                }

                if ($search) {
                    $approvalItems = $approvalItems
                        ->filter(fn(array $item) => $this->matchesApprovalSearch($item, $search))
                        ->values();
                }
            }

            $merged = $hazards
                ->concat($inspections)
                ->concat($approvalItems)
                ->sortByDesc('created_at')
                ->values();

            $currentPage = $request->input('page', 1);
            $pagedData = $merged->forPage($currentPage, $perPage);

            $data = $pagedData;
            $totalMerged = $merged->count();

            $metaExtra = [
                'total'        => $totalMerged,
                'per_page'     => $perPage,
                'current_page' => (int) $currentPage,
                'last_page'    => (int) ceil($totalMerged / max($perPage, 1)),
                'has_more'     => ($currentPage * $perPage) < $totalMerged,
            ];
        }

        return response()->json([
            'status'       => 'success',
            'unread_count' => [
                'total'         => $personalHazardUnread + $personalInspectionUnread + $approvalUnreadCount + $unreadAnnouncementsCount,
                'personal'      => $personalHazardUnread + $personalInspectionUnread + $approvalUnreadCount,
                'announcements' => $unreadAnnouncementsCount,
                'approvals'     => $approvalUnreadCount,
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
            'item_type' => 'required|in:hazard_report,inspection_report,announcement,approval_registration,approval_license,approval_certification',
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
        $user = Auth::user();
        $userId = $user->id;

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

        if ($user->role === 'superadmin') {
            foreach (User::where('registration_status', 'pending')->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_registration',
                ], ['read_at' => now()]);
            }

            foreach (UserLicense::where('approval_status', 'pending')->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_license',
                ], ['read_at' => now()]);
            }

            foreach (UserCertification::where('approval_status', 'pending')->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_certification',
                ], ['read_at' => now()]);
            }
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'All items marked as read',
        ]);
    }

    private function pendingRegistrationItems($readIds)
    {
        return User::where('registration_status', 'pending')
            ->latest('created_at')
            ->get()
            ->map(function (User $user) use ($readIds) {
                return $this->formatApprovalRegistration($user, $readIds->contains($user->id));
            });
    }

    private function pendingLicenseItems($readIds)
    {
        return UserLicense::with('user')
            ->where('approval_status', 'pending')
            ->latest('submitted_at')
            ->latest('created_at')
            ->get()
            ->map(function (UserLicense $license) use ($readIds) {
                return $this->formatApprovalLicense($license, $readIds->contains($license->id));
            });
    }

    private function pendingCertificationItems($readIds)
    {
        return UserCertification::with('user')
            ->where('approval_status', 'pending')
            ->latest('submitted_at')
            ->latest('created_at')
            ->get()
            ->map(function (UserCertification $certification) use ($readIds) {
                return $this->formatApprovalCertification($certification, $readIds->contains($certification->id));
            });
    }

    private function formatApprovalRegistration(User $user, bool $isRead): array
    {
        return [
            'id'              => $user->id,
            'item_type'       => 'approval_registration',
            'title'           => 'Registrasi Akun Baru',
            'description'     => 'Mengajukan pembuatan akun SapaHSE',
            'approval_status' => 'pending',
            'submitted_at'    => $user->created_at?->toIso8601String(),
            'is_read'         => $isRead,
            'submitter'       => [
                'id'             => $user->id,
                'full_name'      => $user->full_name,
                'employee_id'    => $user->employee_id,
                'personal_email' => $user->personal_email,
                'phone_number'   => $user->phone_number,
                'position'       => $user->position,
                'department'     => $user->department,
                'company'        => $user->company,
                'profile_photo'  => $this->resolveFileUrl($user->profile_photo),
            ],
            'created_at'      => $user->created_at?->toIso8601String(),
            'time_ago'        => $user->created_at?->diffForHumans(),
        ];
    }

    private function formatApprovalLicense(UserLicense $license, bool $isRead): array
    {
        $submittedAt = $license->submitted_at ?? $license->created_at;
        $submitter = $license->user;

        return [
            'id'              => $license->id,
            'item_type'       => 'approval_license',
            'title'           => $license->name,
            'description'     => 'Pengajuan input lisensi',
            'approval_status' => $license->approval_status ?? 'pending',
            'rejection_reason' => $license->rejection_reason,
            'submitted_at'    => $submittedAt?->toIso8601String(),
            'is_read'         => $isRead,
            'submitter'       => $submitter ? [
                'id'             => $submitter->id,
                'full_name'      => $submitter->full_name,
                'employee_id'    => $submitter->employee_id,
                'personal_email' => $submitter->personal_email,
                'phone_number'   => $submitter->phone_number,
                'position'       => $submitter->position,
                'department'     => $submitter->department,
                'company'        => $submitter->company,
                'profile_photo'  => $this->resolveFileUrl($submitter->profile_photo),
            ] : null,
            'item'            => [
                'id'             => $license->id,
                'name'           => $license->name,
                'license_number' => $license->license_number,
                'obtained_at'    => $license->obtained_at?->format('Y-m-d'),
                'expired_at'     => $license->expired_at?->format('Y-m-d'),
                'status'         => $license->status,
                'file_url'       => $this->resolveFileUrl($license->file_path),
            ],
            'created_at'      => $submittedAt?->toIso8601String(),
            'time_ago'        => $submittedAt?->diffForHumans(),
        ];
    }

    private function formatApprovalCertification(UserCertification $certification, bool $isRead): array
    {
        $submittedAt = $certification->submitted_at ?? $certification->created_at;
        $submitter = $certification->user;

        return [
            'id'              => $certification->id,
            'item_type'       => 'approval_certification',
            'title'           => $certification->name,
            'description'     => 'Pengajuan input sertifikat',
            'approval_status' => $certification->approval_status ?? 'pending',
            'rejection_reason' => $certification->rejection_reason,
            'submitted_at'    => $submittedAt?->toIso8601String(),
            'is_read'         => $isRead,
            'submitter'       => $submitter ? [
                'id'             => $submitter->id,
                'full_name'      => $submitter->full_name,
                'employee_id'    => $submitter->employee_id,
                'personal_email' => $submitter->personal_email,
                'phone_number'   => $submitter->phone_number,
                'position'       => $submitter->position,
                'department'     => $submitter->department,
                'company'        => $submitter->company,
                'profile_photo'  => $this->resolveFileUrl($submitter->profile_photo),
            ] : null,
            'item'            => [
                'id'          => $certification->id,
                'name'        => $certification->name,
                'issuer'      => $certification->issuer,
                'obtained_at' => $certification->obtained_at?->format('Y-m-d'),
                'expired_at'  => $certification->expired_at?->format('Y-m-d'),
                'status'      => $certification->status,
                'file_url'    => $this->resolveFileUrl($certification->file_path),
            ],
            'created_at'      => $submittedAt?->toIso8601String(),
            'time_ago'        => $submittedAt?->diffForHumans(),
        ];
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

    private function matchesApprovalSearch(array $item, string $search): bool
    {
        $needle = strtolower(trim($search));
        if ($needle === '') {
            return true;
        }

        $submitter = $item['submitter'] ?? [];
        $approvalItem = $item['item'] ?? [];

        $haystack = [
            (string) ($item['title'] ?? ''),
            (string) ($item['description'] ?? ''),
            (string) ($submitter['full_name'] ?? ''),
            (string) ($submitter['employee_id'] ?? ''),
            (string) ($submitter['department'] ?? ''),
            (string) ($submitter['company'] ?? ''),
            (string) ($approvalItem['name'] ?? ''),
            (string) ($approvalItem['license_number'] ?? ''),
            (string) ($approvalItem['issuer'] ?? ''),
        ];

        foreach ($haystack as $value) {
            if ($value !== '' && stripos($value, $needle) !== false) {
                return true;
            }
        }

        return false;
    }

    private function formatHazard(HazardReport $report, ?string $userId): array
    {
        $dueDate  = $report->due_date; // Carbon|null (cast on model)
        $now      = now();
        $sisaHari = $dueDate
            ? (int) $now->diffInDays($dueDate, false)
            : null;
        [$categoryCodes, $categoryNames] = $this->resolveHazardCategories($report->hazard_category);
        $hazardSubcategories = $this->tokenizeCsvPreserveCase($report->hazard_subcategory);

        return [
            'id'                  => $report->id,
            'item_type'           => 'hazard_report',
            'ticket_number'       => $report->ticket_number,
            'title'               => $report->title,
            'description'         => $report->description,
            'status'              => $report->status,
            'sub_status'          => $report->sub_status,
            'location'            => $report->location,
            'image_url'           => $report->image_url,
            'is_read'             => $userId ? $report->isReadBy($userId) : false,
            'reported_by'         => $report->user ? $report->user->only(['full_name', 'employee_id', 'department', 'company']) : null,
            'created_at'          => $report->created_at?->toIso8601String(),
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
            'due_date'            => $dueDate?->toDateTimeString(),
            'due_date_human'      => $dueDate?->translatedFormat('d M Y'),
            'sisa_hari'           => $sisaHari,
            'is_overdue'          => $dueDate !== null && $dueDate->isPast(),
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
            'company'         => $report->company,
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
        $expiresAt = ($a->is_urgent && $a->created_at)
            ? $a->created_at->copy()->addDays(3)->toIso8601String()
            : null;
        return [
            'id'        => $a->id,
            'item_type' => 'announcement',
            'title'     => $a->title,
            'body'      => $a->body,
            'is_urgent' => $a->is_urgent,
            'expires_at' => $expiresAt,
            'image_url' => $this->resolveFileUrl($a->image_url),
            'subtitle'  => $creatorName,
            'from'      => $creatorName,
            'from_name' => $creatorName,
            'is_read'   => $userId ? $a->isReadBy($userId) : false,
            'created_by' => $a->creator ? $a->creator->only(['full_name', 'position', 'company']) : null,
            'created_at' => $a->created_at?->toIso8601String(),
            'time_ago'   => $a->created_at?->diffForHumans(),
        ];
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
