<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\HazardCategory;
use App\Models\ProfileChangeRequest;
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
        $registrationApprovalStatuses = $this->registrationApprovalStatusesFor($user);
        $canSeeRegistrationApprovals = ! empty($registrationApprovalStatuses);

        $readApprovalRegistrationIds = collect();
        $readApprovalLicenseIds = collect();
        $readApprovalCertificationIds = collect();
        $readApprovalProfileChangeIds = collect();

        if ($canSeeRegistrationApprovals) {
            $readApprovalRegistrationIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_registration')
                ->pluck('item_id');
        }

        if ($isAdminOrSA) {
            $readApprovalLicenseIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_license')
                ->pluck('item_id');
            $readApprovalCertificationIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_certification')
                ->pluck('item_id');
            $readApprovalProfileChangeIds = ReadStatus::where('user_id', $userId)
                ->where('item_type', 'approval_profile_change')
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
        $pendingProfileChangeUnread = 0;
        if ($canSeeRegistrationApprovals) {
            $pendingRegistrationUnread = User::whereIn('registration_status', $registrationApprovalStatuses)
                ->whereNotIn('id', $readApprovalRegistrationIds)
                ->count();
        }
        if ($isAdminOrSA) {
            $pendingLicenseUnread = UserLicense::whereIn('approval_status', ['pending', 'pending_changes'])
                ->whereNotIn('id', $readApprovalLicenseIds)
                ->count();
            $pendingCertificationUnread = UserCertification::whereIn('approval_status', ['pending', 'pending_changes'])
                ->whereNotIn('id', $readApprovalCertificationIds)
                ->count();
            $pendingProfileChangeUnread = ProfileChangeRequest::where('approval_status', 'pending')
                ->whereNotIn('id', $readApprovalProfileChangeIds)
                ->count();
        }
        $approvalUnreadCount = $pendingRegistrationUnread + $pendingLicenseUnread + $pendingCertificationUnread + $pendingProfileChangeUnread;

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
            if ($canSeeRegistrationApprovals || $isAdminOrSA) {
                if ($canSeeRegistrationApprovals) {
                    $approvalItems = $approvalItems
                        ->concat($this->pendingRegistrationItems($readApprovalRegistrationIds, $registrationApprovalStatuses));
                }

                if ($isAdminOrSA) {
                    $approvalItems = $approvalItems
                        ->concat($this->pendingLicenseItems($readApprovalLicenseIds))
                        ->concat($this->pendingCertificationItems($readApprovalCertificationIds))
                        ->concat($this->pendingProfileChangeItems($readApprovalProfileChangeIds));
                }

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
            'item_type' => 'required|in:hazard_report,inspection_report,announcement,approval_registration,approval_license,approval_certification,approval_profile_change',
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
        $isAdminOrSA = in_array($user->role, ['admin', 'superadmin'], true);
        $registrationApprovalStatuses = $this->registrationApprovalStatusesFor($user);

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

        if (! empty($registrationApprovalStatuses)) {
            foreach (User::whereIn('registration_status', $registrationApprovalStatuses)->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_registration',
                ], ['read_at' => now()]);
            }
        }

        if ($isAdminOrSA) {
            foreach (UserLicense::whereIn('approval_status', ['pending', 'pending_changes'])->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_license',
                ], ['read_at' => now()]);
            }

            foreach (UserCertification::whereIn('approval_status', ['pending', 'pending_changes'])->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_certification',
                ], ['read_at' => now()]);
            }

            foreach (ProfileChangeRequest::where('approval_status', 'pending')->pluck('id') as $id) {
                ReadStatus::firstOrCreate([
                    'user_id'   => $userId,
                    'item_id'   => $id,
                    'item_type' => 'approval_profile_change',
                ], ['read_at' => now()]);
            }
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'All items marked as read',
        ]);
    }

    public function documentApprovals(Request $request)
    {
        $user = Auth::user();
        if (!in_array($user->role, ['admin', 'superadmin'], true)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Akses ditolak.',
            ], 403);
        }

        $status = $request->input('status', 'pending');
        $search = trim((string) $request->input('search', ''));
        $perPage = max(1, (int) $request->input('per_page', 100));
        $currentPage = max(1, (int) $request->input('page', 1));

        $readLicenseIds = ReadStatus::where('user_id', $user->id)
            ->where('item_type', 'approval_license')
            ->pluck('item_id');
        $readCertificationIds = ReadStatus::where('user_id', $user->id)
            ->where('item_type', 'approval_certification')
            ->pluck('item_id');
        $readProfileChangeIds = ReadStatus::where('user_id', $user->id)
            ->where('item_type', 'approval_profile_change')
            ->pluck('item_id');

        $licenseQuery = UserLicense::with('user', 'reviewer');
        $certificationQuery = UserCertification::with('user', 'reviewer');
        $profileChangeQuery = ProfileChangeRequest::with('user', 'reviewer');

        $statuses = null;
        switch ($status) {
            case 'history':
                $statuses = ['approved', 'rejected'];
                break;
            case 'approved':
                $statuses = ['approved'];
                break;
            case 'rejected':
                $statuses = ['rejected'];
                break;
            case 'all':
                $statuses = null;
                break;
            case 'pending':
            default:
                $statuses = ['pending', 'pending_changes'];
                break;
        }

        if ($statuses !== null) {
            $licenseQuery->whereIn('approval_status', $statuses);
            $certificationQuery->whereIn('approval_status', $statuses);
            $profileChangeQuery->whereIn('approval_status', $statuses);
        }

        if ($search !== '') {
            $licenseQuery->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('license_number', 'like', "%{$search}%")
                    ->orWhere('issuer', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($userQuery) use ($search) {
                        $userQuery->where('full_name', 'like', "%{$search}%")
                            ->orWhere('employee_id', 'like', "%{$search}%")
                            ->orWhere('department', 'like', "%{$search}%");
                    });
            });

            $certificationQuery->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('certification_number', 'like', "%{$search}%")
                    ->orWhere('issuer', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($userQuery) use ($search) {
                        $userQuery->where('full_name', 'like', "%{$search}%")
                            ->orWhere('employee_id', 'like', "%{$search}%")
                            ->orWhere('department', 'like', "%{$search}%");
                    });
            });

            $profileChangeQuery->where(function ($q) use ($search) {
                $q->whereHas('user', function ($userQuery) use ($search) {
                    $userQuery->where('full_name', 'like', "%{$search}%")
                        ->orWhere('employee_id', 'like', "%{$search}%")
                        ->orWhere('department', 'like', "%{$search}%");
                });
            });
        }

        $licenses = $licenseQuery->get()->map(function (UserLicense $license) use ($readLicenseIds) {
            return $this->formatApprovalLicense($license, $readLicenseIds->contains($license->id));
        });

        $certifications = $certificationQuery->get()->map(function (UserCertification $certification) use ($readCertificationIds) {
            return $this->formatApprovalCertification($certification, $readCertificationIds->contains($certification->id));
        });

        $profileChanges = $profileChangeQuery->get()->map(function (ProfileChangeRequest $profileChange) use ($readProfileChangeIds) {
            return $this->formatApprovalProfileChange($profileChange, $readProfileChangeIds->contains($profileChange->id));
        });

        $merged = $licenses
            ->concat($certifications)
            ->concat($profileChanges)
            ->sortByDesc(fn(array $item) => $item['reviewed_at'] ?? $item['created_at'])
            ->values();

        $pagedData = $merged->forPage($currentPage, $perPage)->values();
        $total = $merged->count();

        return response()->json([
            'status' => 'success',
            'meta' => [
                'total'        => $total,
                'per_page'     => $perPage,
                'current_page' => $currentPage,
                'last_page'    => (int) ceil($total / $perPage),
                'has_more'     => ($currentPage * $perPage) < $total,
            ],
            'data' => $pagedData,
        ]);
    }

    private function registrationApprovalStatusesFor(User $user): array
    {
        $statuses = [];

        if ($user->role === 'superadmin' || $user->isHrdReviewer()) {
            $statuses[] = 'pending_hrd';
        }

        if (in_array($user->role, ['admin', 'superadmin'], true)) {
            $statuses[] = 'pending_admin';
        }

        return $statuses;
    }

    private function pendingRegistrationItems(\Illuminate\Support\Collection $readIds, array $statuses)
    {
        return User::with(['reviewer', 'hrdReviewer', 'adminReviewer'])
            ->whereIn('registration_status', $statuses)
            ->latest('created_at')
            ->get()
            ->map(function (User $user) use ($readIds) {
                return $this->formatApprovalRegistration($user, $readIds->contains($user->id));
            });
    }

    private function pendingLicenseItems(\Illuminate\Support\Collection $readIds)
    {
        return UserLicense::with('user', 'reviewer')
            ->whereIn('approval_status', ['pending', 'pending_changes'])
            ->latest('submitted_at')
            ->latest('created_at')
            ->get()
            ->map(function (UserLicense $license) use ($readIds) {
                return $this->formatApprovalLicense($license, $readIds->contains($license->id));
            });
    }

    private function pendingCertificationItems(\Illuminate\Support\Collection $readIds)
    {
        return UserCertification::with('user', 'reviewer')
            ->whereIn('approval_status', ['pending', 'pending_changes'])
            ->latest('submitted_at')
            ->latest('created_at')
            ->get()
            ->map(function (UserCertification $certification) use ($readIds) {
                return $this->formatApprovalCertification($certification, $readIds->contains($certification->id));
            });
    }

    private function pendingProfileChangeItems(\Illuminate\Support\Collection $readIds)
    {
        return ProfileChangeRequest::with('user', 'reviewer')
            ->where('approval_status', 'pending')
            ->latest('submitted_at')
            ->latest('created_at')
            ->get()
            ->map(function (ProfileChangeRequest $request) use ($readIds) {
                return $this->formatApprovalProfileChange($request, $readIds->contains($request->id));
            });
    }

    private function formatApprovalRegistration(User $user, bool $isRead): array
    {
        $reviewer = $user->relationLoaded('reviewer') ? $user->reviewer : null;

        return [
            'id'              => $user->id,
            'item_type'       => 'approval_registration',
            'title'           => 'Registrasi Akun Baru',
            'description'     => 'Mengajukan pembuatan akun SapaHSE',
            'approval_status' => $user->registration_status ?? 'pending',
            'submitted_at'    => $user->created_at?->toIso8601String(),
            'reviewed_at'     => $user->reviewed_at?->toIso8601String(),
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
            'reviewer'        => $reviewer ? [
                'id'            => $reviewer->id,
                'full_name'     => $reviewer->full_name,
                'employee_id'   => $reviewer->employee_id,
                'profile_photo' => $this->resolveFileUrl($reviewer->profile_photo),
            ] : null,
            'created_at'      => $user->created_at?->toIso8601String(),
            'time_ago'        => $user->created_at?->diffForHumans(),
        ];
    }

    private function formatApprovalLicense(UserLicense $license, bool $isRead): array
    {
        $submittedAt = $license->submitted_at ?? $license->created_at;
        $submitter = $license->user;
        $reviewer = $license->relationLoaded('reviewer') ? $license->reviewer : null;

        return [
            'id'              => $license->id,
            'item_type'       => 'approval_license',
            'title'           => $license->name,
            'description'     => $license->license_type === 'mine_permit'
                ? 'Pengajuan Mine Permit'
                : 'Pengajuan input lisensi',
            'approval_status' => $license->approval_status ?? 'pending',
            'rejection_reason' => $license->rejection_reason,
            'submitted_at'    => $submittedAt?->toIso8601String(),
            'reviewed_at'     => $license->reviewed_at?->toIso8601String(),
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
            'reviewer'        => $reviewer ? [
                'id'            => $reviewer->id,
                'full_name'     => $reviewer->full_name,
                'employee_id'   => $reviewer->employee_id,
                'profile_photo' => $this->resolveFileUrl($reviewer->profile_photo),
            ] : null,
            'item'            => [
                'id'             => $license->id,
                'name'           => $license->name,
                'license_number' => $license->license_number,
                'license_type'   => $license->license_type,
                'vehicle_equipment' => $license->vehicle_equipment,
                'sim_type'       => $license->sim_type,
                'sim_indonesia_type' => $license->sim_indonesia_type,
                'issuer'         => $license->issuer,
                'obtained_at'    => $license->obtained_at ? \Carbon\Carbon::parse($license->obtained_at)->format('Y-m-d') : null,
                'expired_at'     => $license->expired_at ? \Carbon\Carbon::parse($license->expired_at)->format('Y-m-d') : null,
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
        $reviewer = $certification->relationLoaded('reviewer') ? $certification->reviewer : null;

        return [
            'id'              => $certification->id,
            'item_type'       => 'approval_certification',
            'title'           => $certification->name,
            'description'     => 'Pengajuan input sertifikat',
            'approval_status' => $certification->approval_status ?? 'pending',
            'rejection_reason' => $certification->rejection_reason,
            'submitted_at'    => $submittedAt?->toIso8601String(),
            'reviewed_at'     => $certification->reviewed_at?->toIso8601String(),
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
            'reviewer'        => $reviewer ? [
                'id'            => $reviewer->id,
                'full_name'     => $reviewer->full_name,
                'employee_id'   => $reviewer->employee_id,
                'profile_photo' => $this->resolveFileUrl($reviewer->profile_photo),
            ] : null,
            'item'            => [
                'id'                   => $certification->id,
                'name'                 => $certification->name,
                'certification_number' => $certification->certification_number,
                'issuer'               => $certification->issuer,
                'obtained_at'          => $certification->obtained_at ? \Carbon\Carbon::parse($certification->obtained_at)->format('Y-m-d') : null,
                'expired_at'  => $certification->expired_at ? \Carbon\Carbon::parse($certification->expired_at)->format('Y-m-d') : null,
                'status'      => $certification->status,
                'file_url'    => $this->resolveFileUrl($certification->file_path),
            ],
            'created_at'      => $submittedAt?->toIso8601String(),
            'time_ago'        => $submittedAt?->diffForHumans(),
        ];
    }

    private function formatApprovalProfileChange(ProfileChangeRequest $request, bool $isRead): array
    {
        $submittedAt = $request->submitted_at ?? $request->created_at;
        $submitter = $request->user;
        $reviewer = $request->relationLoaded('reviewer') ? $request->reviewer : null;

        $fieldLabels = [
            'employee_id' => 'NIP / Employee ID',
            'full_name' => 'Nama Lengkap',
            'personal_email' => 'Email Pribadi',
            'work_email' => 'Email Kantor',
            'phone_number' => 'Nomor Telepon',
            'position' => 'Posisi',
            'jabatan' => 'Jabatan',
            'department' => 'Departemen',
            'company' => 'Perusahaan Owner',
            'tipe_afiliasi' => 'Tipe Afiliasi',
            'perusahaan_kontraktor' => 'Perusahaan Kontraktor',
            'sub_kontraktor' => 'Sub-Kontraktor',
            'address' => 'Alamat',
        ];

        $changes = [];
        foreach ($request->requested_changes as $field => $newValue) {
            $changes[] = [
                'field' => $field,
                'label' => $fieldLabels[$field] ?? $field,
                'old_value' => $request->original_values[$field] ?? null,
                'new_value' => $newValue,
            ];
        }

        return [
            'id'              => $request->id,
            'item_type'       => 'approval_profile_change',
            'title'           => 'Perubahan Profil',
            'description'     => 'Pengajuan perubahan data profil',
            'approval_status' => $request->approval_status ?? 'pending',
            'rejection_reason' => $request->rejection_reason,
            'submitted_at'    => $submittedAt?->toIso8601String(),
            'reviewed_at'     => $request->reviewed_at?->toIso8601String(),
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
            'reviewer'        => $reviewer ? [
                'id'            => $reviewer->id,
                'full_name'     => $reviewer->full_name,
                'employee_id'   => $reviewer->employee_id,
                'profile_photo' => $this->resolveFileUrl($reviewer->profile_photo),
            ] : null,
            'item'            => [
                'id'               => $request->id,
                'requested_changes' => $request->requested_changes,
                'original_values'  => $request->original_values,
                'changes'          => $changes,
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
        $reviewer = $item['reviewer'] ?? [];
        $approvalItem = $item['item'] ?? [];

        $haystack = [
            (string) ($item['title'] ?? ''),
            (string) ($item['description'] ?? ''),
            (string) ($submitter['full_name'] ?? ''),
            (string) ($submitter['employee_id'] ?? ''),
            (string) ($submitter['department'] ?? ''),
            (string) ($submitter['company'] ?? ''),
            (string) ($reviewer['full_name'] ?? ''),
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
