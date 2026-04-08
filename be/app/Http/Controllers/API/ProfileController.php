<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

class ProfileController extends Controller
{
    // GET /api/profile
    public function getProfile()
    {
        return response()->json([
            'status' => 'success',
            'data'   => $this->formatUser(Auth::user()),
        ]);
    }

    // POST /api/profile
    public function updateProfile(Request $request)
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $request->validate([
            'full_name'     => 'nullable|string|max:100',
            'phone_number'  => 'nullable|string|max:20',
            'position'      => 'nullable|string|max:100',
            'department'    => 'nullable|string|max:100',
            'profile_photo' => 'nullable|image|max:2048',
        ]);

        if ($request->filled('full_name'))    $user->full_name    = $request->full_name;
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
            'new_password'     => 'required|min:6|confirmed',
        ]);

        if (! Hash::check($request->current_password, $user->password_hash)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Current password is incorrect',
            ], 422);
        }

        if (Hash::check($request->new_password, $user->password_hash)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'New password must be different from current password',
            ], 422);
        }

        $user->password_hash = Hash::make($request->new_password);
        $user->save();
        $user->tokens()->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Password changed successfully. Please log in again.',
        ]);
    }

    private function formatUser($user): array
    {
        return [
            'id'            => $user->id,
            'nik'           => $user->nik,
            'employee_id'   => $user->employee_id,
            'full_name'     => $user->full_name,
            'email'         => $user->email,
            'phone_number'  => $user->phone_number,
            'position'      => $user->position,
            'department'    => $user->department,
            'profile_photo' => $user->profile_photo
                ? asset('storage/' . $user->profile_photo)
                : null,
            'role'          => $user->role,
            'is_active'     => $user->is_active,
        ];
    }
}