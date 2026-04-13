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
            'full_name'     => 'nullable|string|max:100',
            'work_email'    => 'nullable|email|max:150|unique:users,work_email,' . $user->id,
            'phone_number'  => 'nullable|string|max:20',
            'position'      => 'nullable|string|max:100',
            'department'    => 'nullable|string|max:100',
            'profile_photo' => 'nullable|image|max:2048',
        ]);

        if ($request->filled('full_name'))    $user->full_name    = $request->full_name;
        if ($request->filled('work_email'))   $user->work_email   = $request->work_email;
        if ($request->filled('phone_number')) $user->phone_number = $request->phone_number;
        if ($request->filled('position'))     $user->position     = $request->position;
        if ($request->filled('department'))   $user->department   = $request->department;

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
        ]);

        if (! Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Password saat ini tidak benar. Silakan coba lagi.',
            ], 422);
        }

        if (Hash::check($request->new_password, $user->password)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Password baru harus berbeda dari password saat ini',
            ], 422);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();
        $user->tokens()->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Password berhasil diubah. Silakan Login kembali.',
        ]);
    }

 // DELETE /api/profile
    public function destroyAccount()
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();
        
        // Hapus token session
        $user->tokens()->delete();
        
        // Hapus data
        $user->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Account deleted successfully.',
        ]);
    }

    // POST /api/profile/license
    public function storeLicense(Request $request)
    {
        $request->validate([
            'name'           => 'required|string|max:150',
            'license_number' => 'required|string|max:100',
            'expired_at'     => 'nullable|date',
            'status'         => 'required|string|max:50',
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

    // POST /api/profile/certification
    public function storeCertification(Request $request)
    {
        $request->validate([
            'name'   => 'required|string|max:150',
            'issuer' => 'required|string|max:150',
            'year'   => 'nullable|integer',
            'status' => 'required|string|max:50',
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

    // POST /api/profile/medical
    public function storeMedical(Request $request)
    {
        $request->validate([
            'checkup_date'      => 'nullable|date',
            'blood_type'        => 'nullable|string|max:10',
            'height'            => 'nullable|numeric',
            'weight'            => 'nullable|numeric',
            'blood_pressure'    => 'nullable|string|max:20',
            'allergies'         => 'nullable|string',
            'result'            => 'nullable|string|max:200',
            'next_checkup_date' => 'nullable|date',
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        $medical = $user->medicals()->create($request->only(
            'checkup_date', 'blood_type', 'height', 'weight', 'blood_pressure', 'allergies', 'result', 'next_checkup_date'
        ));

        return response()->json([
            'status'  => 'success',
            'message' => 'Medical record added successfully.',
            'data'    => $medical,
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
            'profile_photo'  => $user->profile_photo
                ? asset('storage/' . $user->profile_photo)
                : null,
            'role'           => $user->role,
            'is_active'      => $user->is_active,
            'licenses'       => $user->relationLoaded('licenses') ? $user->licenses->map(fn($l) => [
                'id'             => $l->id,
                'user_id'        => $l->user_id,
                'name'           => $l->name,
                'license_number' => $l->license_number,
                'expiry_date'     => $l->expired_at?->format('Y-m-d'),
                'status'         => $l->status,
            ]) : [],
            'certifications' => $user->relationLoaded('certifications') ? $user->certifications->map(fn($c) => [
                'id'     => $c->id,
                'user_id'       => $c->user_id,
                'name'   => $c->name,
                'issuer' => $c->issuer,
                'year'   => $c->year,
                'status' => $c->status,
            ]) : [],
            'medicals'       => $user->relationLoaded('medicals') ? $user->medicals->map(fn($m) => [
                'id'               => $m->id,
                'examination_date' => $m->checkup_date?->format('Y-m-d'), 
                'blood_type'       => $m->blood_type,
                'height_cm'        => $m->height,       
                'weight_kg'        => $m->weight,       
                'blood_pressure'   => $m->blood_pressure,
                'allergy'          => $m->allergies,    
                'mcu_status'       => $m->result,      
                'next_mcu_date'    => $m->next_checkup_date?->format('Y-m-d'),
            ]) : [],
        ];
    }
}