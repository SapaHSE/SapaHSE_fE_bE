<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

class ProfileController extends Controller
{
    // GET /api/profile
    public function getProfile()
    {
        /** @var User $user */
        $user = User::with(['licenses', 'certifications', 'medicals' => function ($q) {
            $q->orderBy('checkup_date', 'desc');
        }])->findOrFail(Auth::id());

        return response()->json([
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
            'full_name'      => 'nullable|string|max:100',
            'personal_email'  => 'required|email|max:150|unique:users,personal_email,' . $user->id,
            'work_email'     => 'nullable|email|max:150|unique:users,work_email,' . $user->id,
            'phone_number'   => 'nullable|string|max:20',
            'position'      => 'nullable|string|max:100',
            'department'   => 'nullable|string|max:100',
            'company'      => 'nullable|string|max:100',
            'profile_photo'  => 'nullable|image|max:2048',
        ]);

        if ($request->filled('full_name'))      $user->full_name      = $request->full_name;
        if ($request->filled('personal_email')) $user->personal_email = $request->personal_email;
        if ($request->filled('work_email'))    $user->work_email    = $request->work_email;
        if ($request->filled('phone_number')) $user->phone_number = $request->phone_number;
        if ($request->filled('position'))     $user->position     = $request->position;
        if ($request->filled('department'))   $user->department   = $request->department;
        if ($request->filled('company'))      $user->company      = $request->company;

        if ($request->hasFile('profile_photo')) {
            if ($user->profile_photo) {
                Storage::disk('public')->delete($user->profile_photo);
            }
            $user->profile_photo = $request->file('profile_photo')->store('avatars', 'public');
        }

        $user->save();

        return response()->json([
            'status'  => 'success',
            'message' => 'Profile updated successfully',
            'data'    => $this->formatUser($user),
        ]);
    }

    // POST /api/profile/change-password
    public function changePassword(Request $request)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $request->validate([
            'current_password' => 'required',
            'new_password'     => 'required|min:8|confirmed',
        ], [
            'new_password.min'       => 'Password baru minimal 8 karakter.',
            'new_password.confirmed' => 'Konfirmasi password tidak cocok.',
        ]);

        if (! Hash::check($request->current_password, $user->password_hash)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Password saat ini tidak sesuai.',
            ], 422);
        }

        if (Hash::check($request->new_password, $user->password_hash)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Password baru tidak boleh sama dengan password saat ini.',
            ], 422);
        }

        $user->password_hash = Hash::make($request->new_password);
        $user->save();
        $user->tokens()->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Password berhasil diubah. Silakan login kembali.',
        ]);
    }

    // DELETE /api/profile
    public function destroyAccount()
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        
        // Hapus token session
        $user->tokens()->delete();
        
        // Hapus data (Soft delete jika mau atau hard delete). Model saat ini tdk pakai softDelete
        $user->delete();

        return response()->json([
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
            'expired_at'     => 'nullable|date', 
            'status'         => 'required|string|in:active,expired,suspended',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        $license = $user->licenses()->create($request->only(
            'name', 'license_number', 'expired_at', 'status'
        ));

        return response()->json([
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
            'expired_at'     => 'nullable|date',
            'status'         => 'required|string|in:active,expired,suspended',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();
        $license = $user->licenses()->findOrFail($id);

        $license->update($request->only(
            'name', 'license_number', 'expired_at', 'status'
        ));

        return response()->json([
            'status'  => 'success',
            'message' => 'License updated successfully.',
            'data'    => $license,
        ]);
    }

    // DELETE /api/profile/license/{id}
    public function destroyLicense($id)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        $license = $user->licenses()->findOrFail($id);
        $license->delete();

        return response()->json([
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
                'active' => 'active',
                'expired' => 'expired'
            ];
            $input['status'] = $statusMap[$input['status']] ?? 'active';
        }
        $request->merge($input);

        $request->validate([
            'name'   => 'required|string|max:150',
            'issuer' => 'required|string|max:150',
            'year'   => 'nullable|integer',
            'status' => 'required|string|in:active,expired',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        $cert = $user->certifications()->create($request->only(
            'name', 'issuer', 'year', 'status'
        ));

        return response()->json([
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
                'active' => 'active',
                'expired' => 'expired'
            ];
            $input['status'] = $statusMap[$input['status']] ?? 'active';
        }
        $request->merge($input);

        $request->validate([
            'name'   => 'required|string|max:150',
            'issuer' => 'required|string|max:150',
            'year'   => 'nullable|integer',
            'status' => 'required|string|in:active,expired',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();
        $cert = $user->certifications()->findOrFail($id);

        $cert->update($request->only(
            'name', 'issuer', 'year', 'status'
        ));

        return response()->json([
            'status'  => 'success',
            'message' => 'Certification updated successfully.',
            'data'    => $cert,
        ]);
    }

    // DELETE /api/profile/certification/{id}
    public function destroyCertification($id)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        $cert = $user->certifications()->findOrFail($id);
        $cert->delete();

        return response()->json([
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
            'doctor_notes', 'checklist_items'
        ));

        return response()->json([
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
            'doctor_notes', 'checklist_items'
            ));

        return response()->json([
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

        return response()->json([
            'status'  => 'success',
            'message' => 'Medical record deleted successfully.',
        ]);
    }

    private function formatUser($user): array
    {
        return [
            'id'             => $user->id,
            'employee_id'    => $user->employee_id,
            'full_name'      => $user->full_name,
            'personal_email' => $user->personal_email,
            'work_email'     => $user->work_email,
            'phone_number'   => $user->phone_number,
            'position'       => $user->position,
            'department'     => $user->department,
            'company'        => $user->company,
            'profile_photo'  => $user->profile_photo
                ? asset('storage/' . $user->profile_photo)
                : null,
            'role'           => $user->role,
            'is_active'      => $user->is_active,
            'licenses'       => $user->relationLoaded('licenses') ? $user->licenses->map(fn($l) => [
                'id'             => $l->id,
                'name'           => $l->name,
                'license_number' => $l->license_number,
                'expired_at'     => $l->expired_at?->format('Y-m-d'),
                'status'         => $l->status,
            ]) : [],
            'certifications' => $user->relationLoaded('certifications') ? $user->certifications->map(fn($c) => [
                'id'     => $c->id,
                'name'   => $c->name,
                'issuer' => $c->issuer,
                'year'   => $c->year,
                'status' => $c->status,
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
                'doctor_notes'      => $m->doctor_notes,
                'checklist_items'   => $m->checklist_items ?? [],
            ]) : [],
        ];
    }
}