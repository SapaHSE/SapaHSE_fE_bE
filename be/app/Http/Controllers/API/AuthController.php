<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Mail\VerifyEmailMail;
use App\Models\User;
use App\Models\RegistrationLog;
use App\Models\UserViolation;
use App\Models\UserLicense;
use App\Models\UserCertification;
use App\Mail\RegistrationRejectedMail;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Carbon\Carbon;

class AuthController extends Controller
{
    protected \App\Services\NotificationService $notificationService;

    public function __construct(\App\Services\NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    // POST /api/register
    public function register(Request $request)
    {
        $request->validate([
            'employee_id'    => 'required|string|min:5|max:20|unique:users,employee_id',
            'full_name'      => 'required|string|max:100',
            'personal_email' => 'required|email:rfc,dns|max:150|unique:users',
            'work_email'     => 'nullable|email:rfc,dns|max:150|unique:users',
            'password'       => 'required|string|min:6',
            'phone_number'   => 'required|string|max:20',
            'position'       => 'required|string|max:100',
            'jabatan'        => 'required|string|max:100',
            'department'     => 'required|string|max:100',
            'company'        => 'required|string|max:150',
            'address'        => 'nullable|string|max:500',
            'tipe_afiliasi'  => 'nullable|string|max:50',
            'perusahaan_kontraktor' => 'nullable|string|max:150',
            'sub_kontraktor' => 'nullable|string|max:150',
            'simper'         => 'nullable|string|max:50',
            'profile_photo_url' => 'nullable|url|max:2048',
        ], [
            'employee_id.unique'         => 'NIK sudah terdaftar. Gunakan NIK lain.',
            'employee_id.min'            => 'NIK minimal 5 digit.',
            'employee_id.max'            => 'NIK maksimal 20 digit.',
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
            'jabatan'                   => $request->jabatan,
            'department'                => $request->department,
            'company'                   => $request->company,
            'address'                   => $request->address,
            'tipe_afiliasi'             => $request->tipe_afiliasi,
            'perusahaan_kontraktor'     => $request->perusahaan_kontraktor,
            'sub_kontraktor'            => $request->sub_kontraktor,
            'simper'                    => $request->simper,
            'profile_photo'             => $request->profile_photo_url,
            'role'                      => 'user',
            'is_active'                 => false, // Require admin approval
            'email_verification_token'  => $verificationToken,
        ]);

        // Email verifikasi akan dikirim nanti setelah admin melakukan Approve
        // $verificationUrl = url("/api/email/verify/{$user->id}/{$verificationToken}");
        // Mail::to($user->personal_email)->send(new VerifyEmailMail($verificationUrl, $user->full_name));

        return response()->json([
            'status'  => 'success',
            'message' => 'Registrasi berhasil. Akun Anda sedang menunggu persetujuan administrator. Anda akan menerima email verifikasi setelah akun disetujui.',
            'data'    => ['personal_email' => $user->personal_email],
        ], 201);
    }

    // GET /api/email/verify/{id}/{token}
    // Dibuka melalui browser dari link email
    public function verifyEmail(string $id, string $token)
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
            'personal_email' => 'required|string',
        ]);

        $user = User::where('personal_email', $request->personal_email)
            ->orWhere('work_email', $request->personal_email)
            ->orWhere('employee_id', $request->personal_email)
            ->first();

        if (! $user) {
            return response()->json([
                'status'  => 'error',
                'message' => 'User tidak ditemukan.',
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
            'message' => 'Link verifikasi baru telah dikirim ke email Anda: ' . $user->personal_email,
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
        $user = $request->user();
        if ($user) {
            $user->update(['fcm_token' => null]);
            $user->currentAccessToken()->delete();
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'Logout berhasil.',
        ]);
    }

    // GET /api/users  (admin & superadmin only — untuk fitur Tag Orang — List sederhana)
    public function listUsers(Request $request)
    {
        $search = $request->query('search');

        $users = User::when($request->department, fn($q) => $q->where('department', $request->department))
        ->when($search, fn($q) => $q->where(function($sub) use ($search) {
            $sub->where('full_name', 'like', "%{$search}%")
                ->orWhere('employee_id', 'like', "%{$search}%");
        }))
        ->where('is_active', true)
        ->orderBy('full_name')
        ->select(['id', 'full_name', 'employee_id', 'department', 'position', 'jabatan', 'company', 'role', 'profile_photo'])
        ->get()
        ->map(fn($u) => [
            'id'          => $u->id,
            'full_name'   => $u->full_name,
            'employee_id' => $u->employee_id,
            'department'  => $u->department,
            'position'    => $u->position,
            'jabatan'     => $u->jabatan,
            'company'     => $u->company,
            'role'        => $u->role,
            'photo_url'   => $u->profile_photo ? asset('storage/' . $u->profile_photo) : null,
        ]);

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }



    // ── ADMIN USER MANAGEMENT (CRUD) ──────────────────────────────────────────

    // GET /api/admin/users
    public function adminIndex(Request $request)
    {
        $search = $request->query('search');
        $role = $request->query('role');
        $department = $request->query('department');
        $isActive = $request->query('is_active');
        $regStatus = $request->query('registration_status');

        $users = User::when($search, function ($q) use ($search) {
            $q->where(function ($sub) use ($search) {
                $sub->where('full_name', 'like', "%{$search}%")
                    ->orWhere('employee_id', 'like', "%{$search}%")
                    ->orWhere('personal_email', 'like', "%{$search}%");
            });
        })
        ->when($role, fn($q) => $q->where('role', $role))
        ->when($department, fn($q) => $q->where('department', $department))
        ->when($isActive !== null, fn($q) => $q->where('is_active', filter_var($isActive, FILTER_VALIDATE_BOOLEAN)))
        ->when($regStatus, fn($q) => $q->where('registration_status', $regStatus))
        ->orderBy('registration_status', 'desc') // Pending first usually if alphabetical
        ->orderBy('full_name')
        ->paginate($request->query('per_page', 10));

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }

    // POST /api/admin/users
    public function adminStore(Request $request)
    {
        $request->validate([
            'employee_id'    => 'required|string|min:5|max:20|unique:users,employee_id',
            'full_name'      => 'required|string|max:100',
            'personal_email' => 'required|email|unique:users,personal_email',
            'work_email'     => 'nullable|email|unique:users,work_email',
            'phone_number'   => 'required|string|max:20',
            'position'       => 'required|string|max:100',
            'jabatan'        => 'required|string|max:100',
            'department'     => 'required|string|max:100',
            'company'        => 'required|string|max:100',
            'address'        => 'nullable|string|max:500',
            'tipe_afiliasi'  => 'nullable|string|max:50',
            'perusahaan_kontraktor' => 'nullable|string|max:100',
            'sub_kontraktor' => 'nullable|string|max:100',
            'simper'         => 'nullable|string|max:50',
            'role'           => 'required|string|in:user,admin,superadmin',
            'password'       => 'required|string|min:6',
            'is_active'      => 'boolean',
        ]);

        $user = User::create([
            'employee_id'       => $request->employee_id,
            'full_name'      => $request->full_name,
            'personal_email' => $request->personal_email,
            'work_email'     => $request->work_email,
            'phone_number'   => $request->phone_number,
            'position'       => $request->position,
            'jabatan'        => $request->jabatan,
            'department'     => $request->department,
            'company'        => $request->company,
            'address'        => $request->address,
            'tipe_afiliasi'  => $request->tipe_afiliasi,
            'perusahaan_kontraktor' => $request->perusahaan_kontraktor,
            'sub_kontraktor' => $request->sub_kontraktor,
            'simper'         => $request->simper,
            'role'           => $request->role,
            'password_hash'  => Hash::make($request->password),
            'is_active'      => $request->is_active ?? true,
            'email_verified_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'User created successfully',
            'data'    => $user,
        ], 201);
    }

    // PUT /api/admin/users/{id}
    public function adminUpdate(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        $request->validate([
            'employee_id'    => 'required|string|min:5|max:20|unique:users,employee_id,' . $user->id,
            'full_name'      => 'required|string|max:100',
            'personal_email' => 'required|email|unique:users,personal_email,' . $user->id,
            'work_email'     => 'nullable|email|unique:users,work_email,' . $user->id,
            'phone_number'   => 'required|string|max:20',
            'position'       => 'required|string|max:100',
            'jabatan'        => 'required|string|max:100',
            'department'     => 'required|string|max:100',
            'company'        => 'required|string|max:100',
            'address'        => 'nullable|string|max:500',
            'tipe_afiliasi'  => 'nullable|string|max:50',
            'perusahaan_kontraktor' => 'nullable|string|max:100',
            'sub_kontraktor' => 'nullable|string|max:100',
            'simper'         => 'nullable|string|max:50',
            'role'           => 'required|string|in:user,admin,superadmin',
            'password'       => 'nullable|string|min:6',
            'is_active'      => 'boolean',
        ]);

        $data = $request->except(['password', 'profile_photo']);
        if ($request->filled('password')) {
            $data['password_hash'] = Hash::make($request->password);
        }

        $user->update($data);

        return response()->json([
            'status'  => 'success',
            'message' => 'User updated successfully',
            'data'    => $user,
        ]);
    }

    // DELETE /api/admin/users/{id}
    public function adminDestroy(string $id)
    {
        $user = User::findOrFail($id);
        
        if ($user->id === Auth::id()) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Anda tidak bisa menghapus akun Anda sendiri.',
            ], 403);
        }

        $user->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'User deleted successfully',
        ]);
    }

    // GET /api/admin/violations
    public function adminViolationsIndex(Request $request)
    {
        UserViolation::where('status', 'Aktif')
            ->whereNotNull('expired_at')
            ->where('expired_at', '<', now()->toDateString())
            ->update(['status' => 'Selesai']);

        $search = $request->query('search');
        $status = $request->query('status');
        $perPage = $request->query('per_page', 10);

        $query = UserViolation::with('user:id,full_name,employee_id,profile_photo')
            ->orderBy('date_of_violation', 'desc');

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                    ->orWhere('location', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search) {
                        $uq->where('full_name', 'like', "%{$search}%")
                            ->orWhere('employee_id', 'like', "%{$search}%");
                    });
            });
        }

        if ($status && $status !== 'Semua') {
            $query->where('status', $status);
        }

        $violations = $query->paginate($perPage);

        return response()->json([
            'status'  => 'success',
            'message' => 'Violations retrieved successfully',
            'data'    => $violations,
        ]);
    }

    // POST /api/admin/users/{id}/violations
    public function adminStoreViolation(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        $request->validate([
            'title'             => 'required|string|max:150',
            'description'       => 'nullable|string',
            'location'          => 'nullable|string|max:150',
            'date_of_violation' => 'nullable|date',
            'expired_at'        => 'nullable|date',
            'status'            => 'nullable|string|max:50',
            'sanction'          => 'nullable|string|max:200',
            'file_url'          => 'nullable|string|max:255',
        ]);

        $data = $request->only('title', 'description', 'location', 'date_of_violation', 'expired_at', 'status', 'sanction', 'file_url');
        if (empty($data['date_of_violation'])) {
            $data['date_of_violation'] = now()->toDateString();
        }

        $violation = $user->violations()->create($data);

        return response()->json([
            'status'  => 'success',
            'message' => 'Violation recorded successfully.',
            'data'    => $violation,
        ], 201);
    }

    // PUT /api/admin/violations/{violationId}
    public function adminUpdateViolation(Request $request, string $violationId)
    {
        $violation = UserViolation::findOrFail($violationId);

        $request->validate([
            'title'             => 'required|string|max:150',
            'description'       => 'nullable|string',
            'location'          => 'nullable|string|max:150',
            'date_of_violation' => 'nullable|date',
            'expired_at'        => 'nullable|date',
            'status'            => 'nullable|string|max:50',
            'sanction'          => 'nullable|string|max:200',
            'file_url'          => 'nullable|string|max:255',
        ]);

        $violation->update($request->only(
            'title', 'description', 'location', 'date_of_violation', 'expired_at', 'status', 'sanction', 'file_url'
        ));

        return response()->json([
            'status'  => 'success',
            'message' => 'Violation updated successfully.',
            'data'    => $violation,
        ]);
    }

    // DELETE /api/admin/violations/{violationId}
    public function adminDestroyViolation(string $violationId)
    {
        $violation = UserViolation::findOrFail($violationId);
        $violation->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Violation deleted successfully.',
        ]);
    }

    // PUT /api/admin/licenses/{id}/verify
    public function adminVerifyLicense(Request $request, string $id)
    {
        if ($request->boolean('is_verified', true)) {
            return $this->adminApproveLicense($id);
        }

        $license = UserLicense::findOrFail($id);
        $reason = trim((string) $request->input('reason', 'Ditolak melalui endpoint verifikasi lisensi.'));
        if ($reason === '') {
            $reason = 'Ditolak melalui endpoint verifikasi lisensi.';
        }
        if ($license->approval_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya lisensi dengan status pending yang dapat ditolak.',
            ], 422);
        }

        $license->update([
            'is_verified' => false,
            'approval_status' => 'rejected',
            'rejection_reason' => $reason,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'License verification updated successfully.',
            'data'    => $license,
        ]);
    }

    // PUT /api/admin/certifications/{id}/verify
    public function adminVerifyCertification(Request $request, string $id)
    {
        if ($request->boolean('is_verified', true)) {
            return $this->adminApproveCertification($id);
        }

        $cert = UserCertification::findOrFail($id);
        $reason = trim((string) $request->input('reason', 'Ditolak melalui endpoint verifikasi sertifikasi.'));
        if ($reason === '') {
            $reason = 'Ditolak melalui endpoint verifikasi sertifikasi.';
        }
        if ($cert->approval_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya sertifikasi dengan status pending yang dapat ditolak.',
            ], 422);
        }

        $cert->update([
            'is_verified' => false,
            'approval_status' => 'rejected',
            'rejection_reason' => $reason,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Certification verification updated successfully.',
            'data'    => $cert,
        ]);
    }

    // PUT /api/admin/licenses/{id}/approve
    public function adminApproveLicense(string $id)
    {
        $license = UserLicense::with('user')->findOrFail($id);

        if ($license->approval_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya lisensi dengan status pending yang dapat disetujui.',
            ], 422);
        }

        $license->update([
            'approval_status' => 'approved',
            'is_verified' => true,
            'rejection_reason' => null,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Lisensi berhasil disetujui.',
            'data'    => $license->fresh(),
        ]);
    }

    // POST /api/admin/licenses/{id}/reject
    public function adminRejectLicense(Request $request, string $id)
    {
        $request->validate([
            'reason' => 'required|string|max:2000',
        ]);

        $license = UserLicense::with('user')->findOrFail($id);

        if ($license->approval_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya lisensi dengan status pending yang dapat ditolak.',
            ], 422);
        }

        $license->update([
            'approval_status' => 'rejected',
            'is_verified' => false,
            'rejection_reason' => trim((string) $request->input('reason')),
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Lisensi berhasil ditolak.',
            'data'    => $license->fresh(),
        ]);
    }

    // PUT /api/admin/certifications/{id}/approve
    public function adminApproveCertification(string $id)
    {
        $certification = UserCertification::with('user')->findOrFail($id);

        if ($certification->approval_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya sertifikasi dengan status pending yang dapat disetujui.',
            ], 422);
        }

        $certification->update([
            'approval_status' => 'approved',
            'is_verified' => true,
            'rejection_reason' => null,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Sertifikasi berhasil disetujui.',
            'data'    => $certification->fresh(),
        ]);
    }

    // POST /api/admin/certifications/{id}/reject
    public function adminRejectCertification(Request $request, string $id)
    {
        $request->validate([
            'reason' => 'required|string|max:2000',
        ]);

        $certification = UserCertification::with('user')->findOrFail($id);

        if ($certification->approval_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya sertifikasi dengan status pending yang dapat ditolak.',
            ], 422);
        }

        $certification->update([
            'approval_status' => 'rejected',
            'is_verified' => false,
            'rejection_reason' => trim((string) $request->input('reason')),
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Sertifikasi berhasil ditolak.',
            'data'    => $certification->fresh(),
        ]);
    }

    public function adminApprove(string $id)
    {
        $user = User::findOrFail($id);
        
        if ($user->is_active) {
            return response()->json([
                'status'  => 'error',
                'message' => 'User sudah aktif sebelumnya.',
            ], 422);
        }

        $user->update([
            'is_active' => true,
            'registration_status' => 'approved'
        ]);

        // Kirim notifikasi push
        try {
            $this->notificationService->createNotification(
                $user,
                'registration_approved',
                "Pendaftaran Disetujui",
                "Selamat {$user->full_name}, pendaftaran Anda telah disetujui. Silakan login.",
                ['type' => 'auth']
            );
        } catch (\Exception $e) {
            Log::error('Gagal mengirim notifikasi approve registration: ' . $e->getMessage());
        }

        // Kirim email verifikasi saat di-approve (jika belum pernah diverifikasi)
        if (!$user->email_verified_at) {
            $token = $user->email_verification_token;
            if (!$token) {
                $token = Str::random(64);
                $user->update(['email_verification_token' => $token]);
            }
            
            $verificationUrl = url("/api/email/verify/{$user->id}/{$token}");
            Mail::to($user->personal_email)->send(new VerifyEmailMail($verificationUrl, $user->full_name));
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'User approved successfully. Verification email sent to ' . $user->personal_email,
            'data'    => $user,
        ]);
    }

    // POST /api/admin/users/{id}/reject
    public function adminReject(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        if ($user->registration_status !== 'pending') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya pendaftaran pending yang dapat ditolak.',
            ], 422);
        }

        $reason = $request->input('reason');
        
        // Create registration log entry
        RegistrationLog::create([
            'full_name'        => $user->full_name,
            'employee_id'      => $user->employee_id,
            'personal_email'   => $user->personal_email,
            'phone_number'     => $user->phone_number,
            'company'          => $user->company,
            'department'       => $user->department,
            'rejection_reason' => $reason,
            'rejected_at'      => now(),
        ]);

        // Kirim email penolakan SEBELUM di-delete (agar data email masih ada)
        Mail::to($user->personal_email)->send(new RegistrationRejectedMail($user->full_name, $reason));

        // Delete the user record completely from users table
        $user->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Pendaftaran berhasil ditolak dan data telah dibersihkan. Riwayat tersimpan di log.',
        ]);
    }

    // GET /api/admin/registration-logs
    public function adminRejectedLogs(Request $request)
    {
        $logs = RegistrationLog::orderBy('rejected_at', 'desc')->paginate($request->query('per_page', 10));

        return response()->json([
            'status'  => 'success',
            'message' => 'Registration logs retrieved successfully',
            'data'    => $logs,
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
            'jabatan'        => $user->jabatan,
            'department'     => $user->department,
            'company'        => $user->company,
            'address'        => $user->address,
            'tipe_afiliasi'  => $user->tipe_afiliasi,
            'perusahaan_kontraktor' => $user->perusahaan_kontraktor,
            'sub_kontraktor' => $user->sub_kontraktor,
            'simper'         => $user->simper,
            'profile_photo'  => $user->profile_photo
                ? (filter_var($user->profile_photo, FILTER_VALIDATE_URL)
                    ? $user->profile_photo
                    : asset('storage/' . $user->profile_photo))
                : null,
            'role'           => $user->role,
            'is_active'      => $user->is_active,
        ];
    }
}
