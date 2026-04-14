<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Mail\ResetPasswordMail;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class ForgotPasswordController extends Controller
{
    // POST /api/forgot-password
    // Body: { personal_email }
    public function sendResetOtp(Request $request)
    {
        $request->validate([
            'personal_email' => 'required|string',
        ]);

        $user = User::where('personal_email', $request->personal_email)
                    ->orWhere('work_email', $request->personal_email)
                    ->orWhere('employee_id', $request->personal_email)
                    ->first();

        // Selalu kembalikan success agar tidak bisa ditebak apakah email terdaftar
        if (! $user) {
            return response()->json([
                'status'  => 'success',
                'message' => 'Jika data terdaftar, tautan reset password akan dikirimkan ke email pribadi Anda.',            ]);
        }

        $token = Str::random(64);

        // Simpan token yang sudah di-hash ke tabel password_reset_tokens
        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->personal_email],
            [
                'token'      => Hash::make($token),
                'created_at' => now(),
            ]
        );

        $resetUrl = url("/reset-password/{$token}?email=") . urlencode($user->personal_email);
        Mail::to($user->personal_email)->send(new ResetPasswordMail($resetUrl, $user->full_name));

        return response()->json([
            'status'  => 'success',
            'message' => 'Tautan reset password telah dikirimkan ke email Anda.',
        ]);
    }

    // GET /reset-password/{token} (Web view)
    public function showResetForm(Request $request, $token)
    {
        return view('auth.reset-password-form', [
            'token' => $token,
            'email' => $request->query('email'),
        ]);
    }

    // POST /reset-password (Web form submit)
    public function handleWebReset(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'token'    => 'required|string',
            'password' => 'required|min:6|confirmed',
        ]);

        $record = DB::table('password_reset_tokens')
            ->where('email', $request->email)
            ->first();

        if (! $record || ! Hash::check($request->token, $record->token)) {
            return back()->withInput($request->only('email'))
                         ->withErrors(['email' => 'Tautan reset password tidak valid atau sudah kadaluarsa.']);
        }

        // Cek expiry 15 menit
        if (now()->diffInMinutes($record->created_at, true) > 15) {
            DB::table('password_reset_tokens')->where('email', $request->email)->delete();
            return back()->withErrors(['email' => 'Tautan reset password sudah kadaluarsa. Silakan minta tautan baru.']);
        }

        $user = User::where('personal_email', $request->email)->first();

        if (! $user) {
            return back()->withErrors(['email' => 'User tidak ditemukan.']);
        }

        // Update password
        $user->update(['password_hash' => Hash::make($request->password)]);

        // Hapus token
        DB::table('password_reset_tokens')->where('email', $request->email)->delete();

        // Hapus semua token akses API
        $user->tokens()->delete();

        return view('auth.reset-password-success');
    }
}
