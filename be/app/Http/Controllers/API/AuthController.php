<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Mail\VerifyEmailMail;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    // POST /api/register
    public function register(Request $request)
    {
        $request->validate([
            'employee_id'    => 'required|string|min:10|max:16|unique:users,employee_id',
            'full_name'      => 'required|string|max:100',
            'personal_email' => 'required|email:rfc,dns|max:150|unique:users',
            'work_email'     => 'nullable|email:rfc,dns|max:150|unique:users',
            'password'       => 'required|string|min:6',
            'phone_number'   => 'required|string|max:20',
            'position'       => 'required|string|max:100',
            'department'     => 'required|string|max:100',
            'company'        => 'required|string|max:100',
        ], [
            'employee_id.unique'         => 'NIK sudah terdaftar. Gunakan NIK lain.',
            'employee_id.min'            => 'NIK minimal 10 digit.',
            'employee_id.max'            => 'NIK maksimal 16 digit.',
            'personal_email.email'       => 'Format email tidak valid. Pastikan email Anda benar.',
            'personal_email.unique'      => 'Email ini sudah terdaftar. Gunakan email lain atau login.',
            'work_email.email'           => 'Format email kerja tidak valid atau domain tidak ditemukan.',
            'work_email.unique'          => 'Email kerja ini sudah terdaftar.',
            'password.min'               => 'Password minimal 6 karakter.',
        ]);

        $verificationToken = Str::random(64);

        $user = User::create([
            'employee_id'               => $request->employee_id,
            'full_name'                 => $request->full_name,
            'personal_email'            => $request->personal_email,
            'work_email'                => $request->work_email,
            'password_hash'             => Hash::make($request->password),
            'phone_number'              => $request->phone_number,
            'position'                  => $request->position,
            'department'                => $request->department,
            'company'                   => $request->company,
            'role'                      => 'user',
            'email_verification_token'  => $verificationToken,
        ]);

        // Kirim link verifikasi ke personal email
        $verificationUrl = url("/api/email/verify/{$user->id}/{$verificationToken}");
        Mail::to($user->personal_email)->send(new VerifyEmailMail($verificationUrl, $user->full_name));

        return response()->json([
            'status'  => 'success',
            'message' => 'Registrasi berhasil. Link verifikasi telah dikirim ke email pribadi Anda. Silakan cek inbox dan verifikasi sebelum login.',
            'data'    => ['personal_email' => $user->personal_email],
        ], 201);
    }

    // GET /api/email/verify/{id}/{token}
    // Dibuka melalui browser dari link email
    public function verifyEmail($id, $token)
    {
        $user = User::find($id);

        if (! $user || $user->email_verification_token !== $token) {
            return response()->view('auth.email-verify-result', [
                'success' => false,
                'message' => 'Link verifikasi tidak valid atau sudah digunakan.',
            ], 422);
        }

        if ($user->email_verified_at) {
            return response()->view('auth.email-verify-result', [
                'success' => true,
                'message' => 'Email Anda sudah diverifikasi sebelumnya. Silakan login Aplikasi SapaHSE.',
            ]);
        }

        $user->update([
            'email_verified_at'         => now(),
            'email_verification_token'  => null,
        ]);

        return response()->view('auth.email-verify-result', [
            'success' => true,
            'message' => 'Email berhasil diverifikasi! Silakan kembali ke aplikasi SapaHSE dan login.',
        ]);
    }

    // POST /api/email/resend
    // Body: { personal_email }
    public function resendVerification(Request $request)
    {
        $request->validate([
            'personal_email' => 'required|email',
        ]);

        $user = User::where('personal_email', $request->personal_email)->first();

        if (! $user) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Email tidak ditemukan.',
            ], 404);
        }

        if ($user->email_verified_at) {
            return response()->json([
                'status'  => 'success',
                'message' => 'Email sudah terverifikasi. Silakan login Aplikasi SapaHSE.',
            ]);
        }

        $verificationToken = Str::random(64);
        $user->update(['email_verification_token' => $verificationToken]);

        $verificationUrl = url("/api/email/verify/{$user->id}/{$verificationToken}");
        Mail::to($user->personal_email)->send(new VerifyEmailMail($verificationUrl, $user->full_name));

        return response()->json([
            'status'  => 'success',
            'message' => 'Link verifikasi baru telah dikirim ke email Anda.',
        ]);
    }

    // POST /api/login
    // Field 'login' bisa diisi employee_id, personal_email, atau work_email
    public function login(Request $request)
    {
        $request->validate([
            'login'    => 'required|string',
            'password' => 'required',
        ]);

        $user = User::where('personal_email', $request->login)
            ->orWhere('work_email', $request->login)
            ->orWhere('employee_id', $request->login)
            ->first();

        if (! $user || ! Hash::check($request->password, $user->password_hash)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Kredensial tidak valid. Periksa kembali NIK / Email dan password Anda.',
            ], 401);
        }

        if (! $user->is_active) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Akun Anda tidak aktif. Silakan hubungi administrator.',
            ], 403);
        }

        // Blokir login jika email belum diverifikasi
        if (! $user->email_verified_at) {
            return response()->json([
                'status'  => 'error',
                'code'    => 'email_not_verified',
                'message' => 'Email Anda belum diverifikasi. Silakan cek inbox email pribadi Anda dan klik link verifikasi.',
                'data'    => ['personal_email' => $user->personal_email],
            ], 403);
        }

        $user->tokens()->delete();
        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'status'  => 'success',
            'message' => 'Login berhasil',
            'token'   => $token,
            'data'    => $this->formatUser($user),
        ]);
    }

    // GET /api/me
    public function me(Request $request)
    {
        return response()->json([
            'user' => $request->user(),
        ]);
    }

    // POST /api/logout
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Logout berhasil.',
        ]);
    }

    private function formatUser(User $user): array
    {
        return [
            'id'             => $user->id,
            'employee_id'    => $user->employee_id,
            'full_name'      => $user->full_name,
            'personal_email' => $user->personal_email,
            'work_email'     => $user->work_email,
            'email_verified' => ! is_null($user->email_verified_at),
            'phone_number'   => $user->phone_number,
            'position'       => $user->position,
            'department'     => $user->department,
            'company'        => $user->company,
            'profile_photo'  => $user->profile_photo
                ? asset('storage/' . $user->profile_photo)
                : null,
            'role'           => $user->role,
            'is_active'      => $user->is_active,
        ];
    }
}