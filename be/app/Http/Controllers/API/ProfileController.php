<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\ProfileChangeRequest;
use App\Models\User;
use App\Models\UserLicense;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

class ProfileController extends Controller
{
    protected \App\Services\NotificationService $notificationService;

    public function __construct(\App\Services\NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    // GET /api/profile
    public function getProfile()
    {
        /** @var \App\Models\User $user */
        $user = User::with(['licenses', 'certifications', 'violations' => function ($q) {
            $q->orderBy('date_of_violation', 'desc');
        }, 'medicals' => function ($q) {
            $q->orderBy('checkup_date', 'desc');
        }])->findOrFail(Auth::id());

        if ($user->is_active && $user->email_verified_at) {
            $user->ensureQrCode();
        }

        return \response()->json([
            'status' => 'success',
            'data'   => $this->formatUser($user),
        ]);
    }

    // GET /api/users/{id}/profile  — view another user's full profile (read-only)
    public function getUserProfileById($id)
    {
        $user = User::with(['licenses', 'certifications', 'violations' => function ($q) {
            $q->orderBy('date_of_violation', 'desc');
        }, 'medicals' => function ($q) {
            $q->orderBy('checkup_date', 'desc');
        }])->find($id);

        if (!$user) {
            return \response()->json([
                'status'  => 'error',
                'message' => 'User not found.',
            ], 404);
        }

        return \response()->json([
            'status' => 'success',
            'data'   => $this->formatUser($user),
        ]);
    }


    // POST /api/profile
    public function updateProfile(Request $request)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $request->validate([
            'full_name'     => 'nullable|string|max:100',
            'personal_email'=> 'nullable|email|max:150|unique:users,personal_email,' . $user->id,
            'work_email'    => 'nullable|email|max:150|unique:users,work_email,' . $user->id,
            'phone_number'  => 'nullable|string|max:20',
            'position'      => 'nullable|string|max:100',
            'jabatan'       => 'nullable|string|max:100',
            'department'    => 'nullable|string|max:100',
            'company'       => 'nullable|string|max:100',
            'tipe_afiliasi' => 'nullable|string|max:50',
            'perusahaan_kontraktor' => 'nullable|string|max:100',
            'sub_kontraktor' => 'nullable|string|max:100',
            'address'       => 'nullable|string|max:500',
            'profile_photo' => 'nullable|image|max:2048',
            'profile_photo_url' => 'nullable|url|max:2048',
        ]);

        // Photo update — apply directly without approval
        $photoUpdated = false;
        if ($request->hasFile('profile_photo')) {
            if ($user->profile_photo && !filter_var($user->profile_photo, FILTER_VALIDATE_URL)) {
                Storage::disk('public')->delete($user->profile_photo);
            }
            $user->profile_photo = $request->file('profile_photo')->store('avatars', 'public');
            $photoUpdated = true;
        } elseif ($request->filled('profile_photo_url')) {
            $user->profile_photo = $request->profile_photo_url;
            $photoUpdated = true;
        }

        // Collect non-photo field changes
        $approvalFields = [
            'full_name', 'personal_email', 'work_email', 'phone_number',
            'position', 'jabatan', 'department', 'company',
            'tipe_afiliasi', 'perusahaan_kontraktor', 'sub_kontraktor', 'address',
        ];

        $requestedChanges = [];
        $originalValues = [];

        foreach ($approvalFields as $field) {
            if ($request->has($field)) {
                $newValue = $request->input($field);
                $currentValue = $user->{$field};
                if ((string) $newValue !== (string) $currentValue) {
                    $requestedChanges[$field] = $newValue;
                    $originalValues[$field] = $currentValue;
                }
            }
        }

        // If only photo changed (no other fields), save directly
        if (empty($requestedChanges)) {
            if ($photoUpdated) {
                $user->save();
            }
            return \response()->json([
                'status'  => 'success',
                'message' => 'Profile updated successfully',
                'data'    => $this->formatUser($user->fresh()),
            ]);
        }

        // Save photo if changed
        if ($photoUpdated) {
            $user->save();
        }

        // Cancel any existing pending request from this user
        ProfileChangeRequest::where('user_id', $user->id)
            ->where('approval_status', 'pending')
            ->update(['approval_status' => 'cancelled']);

        // Create a new profile change request
        $changeRequest = ProfileChangeRequest::create([
            'user_id' => $user->id,
            'approval_status' => 'pending',
            'requested_changes' => $requestedChanges,
            'original_values' => $originalValues,
            'submitted_at' => now(),
        ]);

        // Notify admins
        $this->notifyAdminsAboutProfileChange($user->full_name);

        return \response()->json([
            'status'  => 'success',
            'message' => 'Pengajuan perubahan profil berhasil dikirim. Menunggu persetujuan admin.',
            'data'    => $this->formatUser($user->fresh()),
            'change_request' => [
                'id' => $changeRequest->id,
                'approval_status' => $changeRequest->approval_status,
                'requested_changes' => $changeRequest->requested_changes,
                'submitted_at' => $changeRequest->submitted_at?->toIso8601String(),
            ],
        ]);
    }

    // GET /api/profile/change-requests
    public function getProfileChangeRequests()
    {
        $user = Auth::user();

        $requests = ProfileChangeRequest::where('user_id', $user->id)
            ->whereIn('approval_status', ['pending', 'approved', 'rejected'])
            ->orderByDesc('submitted_at')
            ->limit(20)
            ->get()
            ->map(fn($r) => [
                'id' => $r->id,
                'approval_status' => $r->approval_status,
                'requested_changes' => $r->requested_changes,
                'original_values' => $r->original_values,
                'rejection_reason' => $r->rejection_reason,
                'submitted_at' => $r->submitted_at?->toIso8601String(),
                'reviewed_at' => $r->reviewed_at?->toIso8601String(),
                'created_at' => $r->created_at?->toIso8601String(),
            ]);

        return \response()->json([
            'status' => 'success',
            'data' => $requests,
        ]);
    }

    // PUT /admin/profile-change-requests/{id}/approve
    public function adminApproveProfileChange($id)
    {
        $changeRequest = ProfileChangeRequest::findOrFail($id);

        if ($changeRequest->approval_status !== 'pending') {
            return \response()->json([
                'status' => 'error',
                'message' => 'Pengajuan ini sudah diproses sebelumnya.',
            ], 422);
        }

        $user = User::findOrFail($changeRequest->user_id);

        // Apply requested changes to user
        foreach ($changeRequest->requested_changes as $field => $value) {
            $user->{$field} = $value;
        }
        $user->save();

        $changeRequest->update([
            'approval_status' => 'approved',
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        // Notify user
        try {
            $this->notificationService->createNotification(
                $user,
                'profile_change_approved',
                'Perubahan Profil Disetujui',
                'Pengajuan perubahan profil Anda telah disetujui oleh admin.',
                ['type' => 'approval']
            );
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Gagal mengirim notifikasi: ' . $e->getMessage());
        }

        return \response()->json([
            'status' => 'success',
            'message' => 'Perubahan profil berhasil disetujui.',
        ]);
    }

    // POST /admin/profile-change-requests/{id}/reject
    public function adminRejectProfileChange(Request $request, $id)
    {
        $request->validate([
            'reason' => 'required|string|max:500',
        ]);

        $changeRequest = ProfileChangeRequest::findOrFail($id);

        if ($changeRequest->approval_status !== 'pending') {
            return \response()->json([
                'status' => 'error',
                'message' => 'Pengajuan ini sudah diproses sebelumnya.',
            ], 422);
        }

        $changeRequest->update([
            'approval_status' => 'rejected',
            'rejection_reason' => $request->reason,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        // Notify user
        $user = User::find($changeRequest->user_id);
        if ($user) {
            try {
                $this->notificationService->createNotification(
                    $user,
                    'profile_change_rejected',
                    'Perubahan Profil Ditolak',
                    'Pengajuan perubahan profil Anda ditolak. Alasan: ' . $request->reason,
                    ['type' => 'approval']
                );
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error('Gagal mengirim notifikasi: ' . $e->getMessage());
            }
        }

        return \response()->json([
            'status' => 'success',
            'message' => 'Pengajuan perubahan profil ditolak.',
        ]);
    }

    // POST /api/profile/change-password
    public function changePassword(Request $request)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $request->validate([
            'current_password' => 'required',
            'new_password'     => 'required|min:6|confirmed',
        ]);

        if (! Hash::check($request->current_password, $user->password_hash)) {
            return \response()->json([
                'status'  => 'error',
                'message' => 'Current password is incorrect',
            ], 422);
        }

        if (Hash::check($request->new_password, $user->password_hash)) {
            return \response()->json([
                'status'  => 'error',
                'message' => 'New password must be different from current password',
            ], 422);
        }

        $user->password_hash = Hash::make($request->new_password);
        $user->save();
        $user->tokens()->update([
            'revoked_reason' => 'password_changed',
            'expires_at' => now(),
        ]);

        return \response()->json([
            'status'  => 'success',
            'message' => 'Password changed successfully. Please log in again.',
        ]);
    }

    // DELETE /api/profile
    public function destroyAccount()
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        
        // Hapus token session
        $user->tokens()->update([
            'revoked_reason' => 'account_deleted',
            'expires_at' => now(),
        ]);
        
        // Hapus data (Soft delete jika mau atau hard delete). Model saat ini tdk pakai softDelete
        $user->delete();

        return \response()->json([
            'status'  => 'success',
            'message' => 'Account deleted successfully.',
        ]);
    }

    // POST /api/profile/license
    public function storeLicense(Request $request)
    {
        $input = $request->all();
        // Map Indonesian status to DB enum
        if (isset($input['status'])) {
            $statusMap = [
                'Aktif' => 'active',
                'Kadaluarsa' => 'expired',
                'Expired' => 'expired',
                'active' => 'active',
                'expired' => 'expired',
                'suspended' => 'suspended'
            ];
            $input['status'] = $statusMap[$input['status']] ?? 'active';
        }
        $request->merge($input);

        $request->validate([
            'name'           => 'required|string|max:150', 
            'license_number' => 'required|string|max:100',
            'license_type'   => 'nullable|string|max:50',
            'vehicle_equipment' => 'nullable|string|max:150',
            'sim_type'       => 'nullable|string|max:10',
            'sim_indonesia_type' => 'nullable|string|max:20',
            'issuer'         => 'nullable|string|max:100',
            'obtained_at'    => 'nullable|date',
            'expired_at'     => 'nullable|date', 
            'status'         => 'required|string|in:active,expired,suspended',
            'file'           => 'nullable|file|max:5120', // Max 5MB
            'file_url'       => 'nullable|url|max:2048',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        $data = $request->only(
            'name',
            'license_number',
            'license_type',
            'vehicle_equipment',
            'sim_type',
            'sim_indonesia_type',
            'issuer',
            'obtained_at',
            'expired_at',
            'status'
        );
        $data['license_type'] = $data['license_type'] ?? 'general';
        $data['approval_status'] = 'pending';
        $data['is_verified'] = false;
        $data['rejection_reason'] = null;
        $data['reviewed_by'] = null;
        $data['reviewed_at'] = null;
        $data['submitted_at'] = now();
        
        if ($request->hasFile('file')) {
            $data['file_path'] = $request->file('file')->store('licenses', 'public');
        } elseif ($request->filled('file_url')) {
            $data['file_path'] = $request->file_url;
        }

        $license = $user->licenses()->create($data);

        return \response()->json([
            'status'  => 'success',
            'message' => 'License added successfully.',
            'data'    => $license,
        ]);
    }

    // PUT /api/profile/license/{id}
    public function updateLicense(Request $request, $id)
    {
        $input = $request->all();
        if (isset($input['status'])) {
            $statusMap = [
                'Aktif' => 'active',
                'Kadaluarsa' => 'expired',
                'Expired' => 'expired',
                'active' => 'active',
                'expired' => 'expired',
                'suspended' => 'suspended'
            ];
            $input['status'] = $statusMap[$input['status']] ?? 'active';
        }
        $request->merge($input);

        $request->validate([
            'name'           => 'required|string|max:150',
            'license_number' => 'required|string|max:100',
            'license_type'   => 'nullable|string|max:50',
            'vehicle_equipment' => 'nullable|string|max:150',
            'sim_type'       => 'nullable|string|max:10',
            'sim_indonesia_type' => 'nullable|string|max:20',
            'issuer'         => 'nullable|string|max:100',
            'obtained_at'    => 'nullable|date',
            'expired_at'     => 'nullable|date',
            'status'         => 'required|string|in:active,expired,suspended',
            'file'           => 'nullable|file|max:5120',
            'file_url'       => 'nullable|url|max:2048',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();
        $license = $user->licenses()->findOrFail($id);

        $updateData = $request->only(
            'name',
            'license_number',
            'license_type',
            'vehicle_equipment',
            'sim_type',
            'sim_indonesia_type',
            'issuer',
            'obtained_at',
            'expired_at',
            'status'
        );

        if ($request->hasFile('file')) {
            $updateData['file_path'] = $request->file('file')->store('licenses', 'public');
        } elseif ($request->filled('file_url')) {
            $updateData['file_path'] = $request->file_url;
        }

        // Re-approval flow based on current approval_status
        if ($license->approval_status === 'rejected') {
            // Rejected → pending for re-review (existing behavior)
            $updateData['approval_status'] = 'pending';
            $updateData['is_verified'] = false;
            $updateData['rejection_reason'] = null;
            $updateData['reviewed_by'] = null;
            $updateData['reviewed_at'] = null;
            $updateData['submitted_at'] = now();
        } elseif (in_array($license->approval_status, ['approved', 'expired'])) {
            // Approved or expired → pending_changes for re-approval
            $updateData['approval_status'] = 'pending_changes';
            $updateData['is_verified'] = false;
            $updateData['rejection_reason'] = null;
            $updateData['reviewed_by'] = null;
            $updateData['reviewed_at'] = null;
            $updateData['submitted_at'] = now();
        } elseif ($license->approval_status === 'pending') {
            // Already pending (not yet reviewed) — just update submitted_at
            $updateData['submitted_at'] = now();
        }

        $license->update($updateData);

        // Notify admins when a previously approved document needs re-approval
        if (($updateData['approval_status'] ?? null) === 'pending_changes') {
            $this->notifyAdminsAboutPendingChanges(
                $user->full_name,
                $updateData['name'] ?? $license->name,
                'license'
            );
        }

        return \response()->json([
            'status'  => 'success',
            'message' => 'License updated successfully.',
            'data'    => $license->fresh(),
        ]);
    }

    // POST /api/profile/mine-permit/request
    public function requestMinePermit(Request $request)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $existing = $user->licenses()
            ->where('license_type', 'mine_permit')
            ->latest('expired_at')
            ->latest('created_at')
            ->first();

        if ($existing && ! $existing->canBeRenewedNow()) {
            return \response()->json([
                'status' => 'error',
                'message' => UserLicense::renewalBlockedMessage(),
            ], 422);
        }

        if ($existing && in_array($existing->approval_status, ['pending', 'pending_changes'])) {
            return \response()->json([
                'status' => 'error',
                'message' => 'Pengajuan Mine Permit masih menunggu approval.',
            ], 422);
        }

        $payload = [
            'name' => 'Mine Permit',
            'license_type' => 'mine_permit',
            'license_number' => $existing?->license_number ?: 'MP-' . strtoupper((string) $user->employee_id),
            'issuer' => 'PT Bukit Baiduri Energi',
            'status' => 'active',
            'approval_status' => $existing ? 'pending_changes' : 'pending',
            'is_verified' => false,
            'rejection_reason' => null,
            'reviewed_by' => null,
            'reviewed_at' => null,
            'submitted_at' => now(),
        ];

        if ($existing) {
            $existing->update($payload);
            $license = $existing->fresh();
            $message = 'Pengajuan perpanjangan Mine Permit berhasil dikirim.';
        } else {
            $license = $user->licenses()->create($payload);
            $message = 'Pengajuan Mine Permit berhasil dikirim.';
        }

        return \response()->json([
            'status' => 'success',
            'message' => $message,
            'data' => $license,
        ]);
    }

    // DELETE /api/profile/license/{id}
    public function destroyLicense($id)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        $license = $user->licenses()->findOrFail($id);
        $license->delete();

        return \response()->json([
            'status'  => 'success',
            'message' => 'License deleted successfully.',
        ]);
    }

    // POST /api/profile/certification
    public function storeCertification(Request $request)
    {
        $input = $request->all();
        if (isset($input['status'])) {
            $statusMap = [
                'Aktif' => 'active',
                'Kadaluarsa' => 'expired',
                'Expired' => 'expired',
                'active' => 'active',
                'expired' => 'expired'
            ];
            $input['status'] = $statusMap[$input['status']] ?? 'active';
        }
        $request->merge($input);

        $request->validate([
            'name'        => 'required|string|max:150',
            'certification_number' => 'nullable|string|max:100',
            'issuer'      => 'required|string|max:150',
            'obtained_at' => 'nullable|date',
            'expired_at'  => 'nullable|date',
            'status' => 'required|string|in:active,expired',
            'file'   => 'nullable|file|max:5120', // Max 5MB
            'file_url' => 'nullable|url|max:2048',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        $data = $request->only('name', 'certification_number', 'issuer', 'obtained_at', 'expired_at', 'status');
        $data['approval_status'] = 'pending';
        $data['is_verified'] = false;
        $data['rejection_reason'] = null;
        $data['reviewed_by'] = null;
        $data['reviewed_at'] = null;
        $data['submitted_at'] = now();

        if ($request->hasFile('file')) {
            $data['file_path'] = $request->file('file')->store('certifications', 'public');
        } elseif ($request->filled('file_url')) {
            $data['file_path'] = $request->file_url;
        }

        $cert = $user->certifications()->create($data);

        return \response()->json([
            'status'  => 'success',
            'message' => 'Certification added successfully.',
            'data'    => $cert,
        ]);
    }

    // PUT /api/profile/certification/{id}
    public function updateCertification(Request $request, $id)
    {
        $input = $request->all();
        if (isset($input['status'])) {
            $statusMap = [
                'Aktif' => 'active',
                'Kadaluarsa' => 'expired',
                'Expired' => 'expired',
                'active' => 'active',
                'expired' => 'expired'
            ];
            $input['status'] = $statusMap[$input['status']] ?? 'active';
        }
        $request->merge($input);

        $request->validate([
            'name'        => 'required|string|max:150',
            'certification_number' => 'nullable|string|max:100',
            'issuer'      => 'required|string|max:150',
            'obtained_at' => 'nullable|date',
            'expired_at'  => 'nullable|date',
            'status' => 'required|string|in:active,expired',
            'file'   => 'nullable|file|max:5120',
            'file_url' => 'nullable|url|max:2048',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();
        $cert = $user->certifications()->findOrFail($id);

        $updateData = $request->only(
            'name',
            'certification_number',
            'issuer',
            'obtained_at',
            'expired_at',
            'status'
        );

        if ($request->hasFile('file')) {
            $updateData['file_path'] = $request->file('file')->store('certifications', 'public');
        } elseif ($request->filled('file_url')) {
            $updateData['file_path'] = $request->file_url;
        }

        // Re-approval flow based on current approval_status
        if ($cert->approval_status === 'rejected') {
            // Rejected → pending for re-review (existing behavior)
            $updateData['approval_status'] = 'pending';
            $updateData['is_verified'] = false;
            $updateData['rejection_reason'] = null;
            $updateData['reviewed_by'] = null;
            $updateData['reviewed_at'] = null;
            $updateData['submitted_at'] = now();
        } elseif (in_array($cert->approval_status, ['approved', 'expired'])) {
            // Approved or expired → pending_changes for re-approval
            $updateData['approval_status'] = 'pending_changes';
            $updateData['is_verified'] = false;
            $updateData['rejection_reason'] = null;
            $updateData['reviewed_by'] = null;
            $updateData['reviewed_at'] = null;
            $updateData['submitted_at'] = now();
        } elseif ($cert->approval_status === 'pending') {
            // Already pending (not yet reviewed) — just update submitted_at
            $updateData['submitted_at'] = now();
        }

        $cert->update($updateData);

        // Notify admins when a previously approved document needs re-approval
        if (($updateData['approval_status'] ?? null) === 'pending_changes') {
            $this->notifyAdminsAboutPendingChanges(
                $user->full_name,
                $updateData['name'] ?? $cert->name,
                'certification'
            );
        }

        return \response()->json([
            'status'  => 'success',
            'message' => 'Certification updated successfully.',
            'data'    => $cert->fresh(),
        ]);
    }

    // DELETE /api/profile/certification/{id}
    public function destroyCertification($id)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        $cert = $user->certifications()->findOrFail($id);
        $cert->delete();

        return \response()->json([
            'status'  => 'success',
            'message' => 'Certification deleted successfully.',
        ]);
    }

    // POST /api/profile/medical
    public function storeMedical(Request $request)
    {
        $request->validate([
            'title'             => 'nullable|string|max:200',
            'patient_name'      => 'nullable|string|max:150',
            'checkup_date'      => 'nullable|date',
            'blood_type'        => 'nullable|string|max:20',
            'height'            => 'nullable',
            'weight'            => 'nullable',
            'blood_pressure'    => 'nullable|string|max:30',
            'allergies'         => 'nullable|string',
            'result'            => 'nullable|string|max:255',
            'next_checkup_date' => 'nullable|date',
            'doctor_name'       => 'nullable|string|max:150',
            'doctor_contact'    => 'nullable|string|max:50',
            'facility_name'     => 'nullable|string|max:200',
            'facility_contact'  => 'nullable|string|max:50',
            'last_medication'   => 'nullable|string|max:255',
            'current_medication'=> 'nullable|string|max:255',
            'current_illness'   => 'nullable|string',
            'doctor_notes'      => 'nullable|string',
            'checklist_items'   => 'nullable|array',
            'checklist_items.*.label' => 'required|string',
            'checklist_items.*.done'  => 'required|boolean',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        $medical = $user->medicals()->create($request->only(
            'title', 'patient_name',
            'checkup_date', 'blood_type', 'height', 'weight', 'blood_pressure',
            'allergies', 'result', 'next_checkup_date',
            'doctor_name', 'doctor_contact', 'facility_name', 'facility_contact',
            'last_medication', 'current_medication', 'current_illness',
            'doctor_notes', 'checklist_items'
        ));

        return \response()->json([
            'status'  => 'success',
            'message' => 'Medical record added successfully.',
            'data'    => $medical,
        ]);
    }

    // PUT /api/profile/medical/{id}
    public function updateMedical(Request $request, $id)
    {
        $request->validate([
            'title'             => 'nullable|string|max:200',
            'patient_name'      => 'nullable|string|max:150',
            'checkup_date'      => 'nullable|date',
            'blood_type'        => 'nullable|string|max:20',
            'height'            => 'nullable',
            'weight'            => 'nullable',
            'blood_pressure'    => 'nullable|string|max:30',
            'allergies'         => 'nullable|string',
            'result'            => 'nullable|string|max:255',
            'next_checkup_date' => 'nullable|date',
            'doctor_name'       => 'nullable|string|max:150',
            'doctor_contact'    => 'nullable|string|max:50',
            'facility_name'     => 'nullable|string|max:200',
            'facility_contact'  => 'nullable|string|max:50',
            'last_medication'   => 'nullable|string|max:255',
            'current_medication'=> 'nullable|string|max:255',
            'current_illness'   => 'nullable|string',
            'doctor_notes'      => 'nullable|string',
            'checklist_items'   => 'nullable|array',
            'checklist_items.*.label' => 'required|string',
            'checklist_items.*.done'  => 'required|boolean',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();
        $medical = $user->medicals()->findOrFail($id);

        $medical->update($request->only(
            'title', 'patient_name',
            'checkup_date', 'blood_type', 'height', 'weight', 'blood_pressure',
            'allergies', 'result', 'next_checkup_date',
            'doctor_name', 'doctor_contact', 'facility_name', 'facility_contact',
            'last_medication', 'current_medication', 'current_illness',
            'doctor_notes', 'checklist_items'
        ));

        return \response()->json([
            'status'  => 'success',
            'message' => 'Medical record updated successfully.',
            'data'    => $medical,
        ]);
    }

    // DELETE /api/profile/medical/{id}
    public function destroyMedical($id)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        $medical = $user->medicals()->findOrFail($id);
        $medical->delete();

        return \response()->json([
            'status'  => 'success',
            'message' => 'Medical record deleted successfully.',
        ]);
    }

    private function notifyAdminsAboutPendingChanges(string $userName, string $docName, string $type): void
    {
        $admins = \App\Models\User::whereIn('role', ['admin', 'superadmin'])
            ->where('is_active', true)
            ->get();

        $typeLabel = $type === 'license' ? 'Lisensi' : 'Sertifikat';
        $message = "{$userName} mengajukan perubahan pada {$typeLabel} {$docName}";

        foreach ($admins as $admin) {
            try {
                $this->notificationService->createNotification(
                    $admin,
                    $type === 'license' ? 'license_pending_changes' : 'certification_pending_changes',
                    "Perubahan {$typeLabel}",
                    $message,
                    ['type' => 'approval']
                );
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error(
                    'Gagal mengirim notifikasi pending_changes: ' . $e->getMessage()
                );
            }
        }
    }

    private function notifyAdminsAboutProfileChange(string $userName): void
    {
        $admins = \App\Models\User::whereIn('role', ['admin', 'superadmin'])
            ->where('is_active', true)
            ->get();

        $message = "{$userName} mengajukan perubahan data profil";

        foreach ($admins as $admin) {
            try {
                $this->notificationService->createNotification(
                    $admin,
                    'profile_change_pending',
                    'Perubahan Profil',
                    $message,
                    ['type' => 'approval']
                );
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error(
                    'Gagal mengirim notifikasi profile_change: ' . $e->getMessage()
                );
            }
        }
    }

    private function formatUser(\App\Models\User $user): array
    {
        return [
            'id'             => $user->id,
            'employee_id'    => $user->employee_id,
            'full_name'      => $user->full_name,
            'personal_email' => $user->personal_email,
            'work_email'     => $user->work_email,
            'qr_code'        => $user->qr_code,
            'phone_number'   => $user->phone_number,
            'position'       => $user->position,
            'jabatan'        => $user->jabatan,
            'department'     => $user->department,
            'company'        => $user->company,
            'company_detail' => $user->companyDetailPayload(),
            'address'        => $user->address,
            'tipe_afiliasi'  => $user->tipe_afiliasi,
            'perusahaan_kontraktor' => $user->perusahaan_kontraktor,
            'sub_kontraktor' => $user->sub_kontraktor,
            'simper'         => $user->simper,
            'profile_photo'  => $user->profile_photo
                ? (\filter_var($user->profile_photo, FILTER_VALIDATE_URL)
                    ? $user->profile_photo
                    : \asset('storage/' . $user->profile_photo))
                : null,
            'role'           => $user->role,
            'is_active'      => $user->is_active,
            'status_text'    => ($user->is_active ? 'Aktif' : 'Non-Aktif') . ' atas nama ' . $user->full_name,
            'licenses'       => $user->relationLoaded('licenses') ? $user->licenses->map(fn($l) => [
                'id'             => $l->id,
                'name'           => $l->name,
                'license_number' => $l->license_number,
                'license_type'   => $l->license_type,
                'vehicle_equipment' => $l->vehicle_equipment,
                'sim_type'       => $l->sim_type,
                'sim_indonesia_type' => $l->sim_indonesia_type,
                'issuer'         => $l->issuer,
                'obtained_at'    => $l->obtained_at?->format('Y-m-d'),
                'expired_at'     => $l->expired_at?->format('Y-m-d'),
                'status'         => $l->status,
                'is_verified'    => (bool) $l->is_verified,
                'approval_status'=> $l->approval_status,
                'rejection_reason' => $l->rejection_reason,
                'submitted_at'   => $l->submitted_at?->toIso8601String(),
                'reviewed_at'    => $l->reviewed_at?->toIso8601String(),
                'reviewed_by'    => $l->reviewed_by,
                'file_url'       => $l->file_path
                    ? (\filter_var($l->file_path, FILTER_VALIDATE_URL)
                        ? $l->file_path
                        : \asset('storage/' . $l->file_path))
                    : null,
            ]) : [],
            'certifications' => $user->relationLoaded('certifications') ? $user->certifications->map(fn($c) => [
                'id'          => $c->id,
                'name'        => $c->name,
                'certification_number' => $c->certification_number,
                'issuer'      => $c->issuer,
                'obtained_at' => $c->obtained_at?->format('Y-m-d'),
                'expired_at'  => $c->expired_at?->format('Y-m-d'),
                'status'      => $c->status,
                'is_verified' => (bool) $c->is_verified,
                'approval_status'=> $c->approval_status,
                'rejection_reason' => $c->rejection_reason,
                'submitted_at'   => $c->submitted_at?->toIso8601String(),
                'reviewed_at'    => $c->reviewed_at?->toIso8601String(),
                'reviewed_by'    => $c->reviewed_by,
                'file_url'    => $c->file_path
                    ? (\filter_var($c->file_path, FILTER_VALIDATE_URL)
                        ? $c->file_path
                        : \asset('storage/' . $c->file_path))
                    : null,
            ]) : [],
            'medicals'       => $user->relationLoaded('medicals') ? $user->medicals->map(fn($m) => [
                'id'                => $m->id,
                'title'             => $m->title,
                'patient_name'      => $m->patient_name,
                'checkup_date'      => $m->checkup_date?->format('Y-m-d'),
                'blood_type'        => $m->blood_type,
                'height'            => $m->height,
                'weight'            => $m->weight,
                'blood_pressure'    => $m->blood_pressure,
                'allergies'         => $m->allergies,
                'result'            => $m->result,
                'next_checkup_date' => $m->next_checkup_date?->format('Y-m-d'),
                'doctor_name'       => $m->doctor_name,
                'doctor_contact'    => $m->doctor_contact,
                'facility_name'     => $m->facility_name,
                'facility_contact'  => $m->facility_contact,
                'last_medication'   => $m->last_medication,
                'current_medication'=> $m->current_medication,
                'current_illness'   => $m->current_illness,
                'doctor_notes'      => $m->doctor_notes,
                'checklist_items'   => $m->checklist_items ?? [],
            ]) : [],
            'violations'     => $user->relationLoaded('violations') ? $user->violations->map(fn($v) => [
                'id'                => $v->id,
                'title'             => $v->title,
                'description'       => $v->description,
                'location'          => $v->location,
                'date_of_violation' => $v->date_of_violation?->format('Y-m-d'),
                'expired_at'        => $v->expired_at?->format('Y-m-d'),
                'status'            => $v->status,
                'sanction'          => $v->sanction,
                'file_url'          => $v->file_url,
            ]) : [],
        ];
    }
}
