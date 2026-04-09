<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    // POST /api/register
    public function register(Request $request)
    {
        $request->validate([
            'nik'          => 'required|string|size:16|unique:users',
            'employee_id'  => 'nullable|string|max:20|unique:users,employee_id,NULL,id,employee_id,NULL',
            'full_name'    => 'required|string|max:100',
            'email'        => 'required|email|unique:users',
            'password'     => 'required|min:8',
            'phone_number' => 'nullable|string|max:20',
            'position'     => 'nullable|string|max:100',
            'department'   => 'nullable|string|max:100',
        ]);

        $user = User::create([
            'nik'           => $request->nik,
            'employee_id'   => $request->employee_id ?? null,
            'full_name'     => $request->full_name,
            'email'         => $request->email,
            'password_hash' => Hash::make($request->password),
            'phone_number'  => $request->phone_number,
            'position'      => $request->position,
            'department'    => $request->department,
            'role'          => 'user',
        ]);

        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'status'  => 'success',
            'message' => 'Registration successful',
            'token'   => $token,
            'user' => $user,
            'data'    => $this->formatUser($user),
        ], 201);
    }

    // POST /api/login
    // Field 'login' diisi NIK
    public function login(Request $request)
    {
        $request->validate([
            'login'    => 'required|string',
            'password' => 'required',
        ]);

        $user = User::where('nik', $request->login)
            ->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Invalid credentials. Please check your NIK/Employee ID/Email and password.',
            ], 401);
        }

        if (! $user->is_active) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Your account is inactive. Please contact the administrator.',
            ], 403);
        }

        $user->tokens()->delete();
        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'status'  => 'success',
            'message' => 'Login successful',
            'token'   => $token,
            'data'    => $this->formatUser($user),
        ]);
    }

        public function me(Request $request)
    {
        return response()->json([
            'user' => $request->user()
        ]);
    }

    // POST /api/logout
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Logged out successfully',
        ]);
    }

    private function formatUser(User $user): array
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