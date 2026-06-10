<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Mail\VerifyEmailMail;
use App\Models\User;
use App\Models\RegistrationLog;
use App\Models\ReadStatus;
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
            'employee_id'    => 'nullable|string|min:5|max:20|unique:users,employee_id',
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
            'employee_id.unique'         => 'NIP sudah terdaftar. Gunakan NIP lain.',
            'employee_id.min'            => 'NIP minimal 5 digit.',
            'employee_id.max'            => 'NIP maksimal 20 digit.',
            'personal_email.email'       => 'Format email tidak valid. Pastikan email Anda benar.',
            'personal_email.unique'      => 'Email ini sudah terdaftar. Gunakan email lain atau login.',
            'work_email.email'           => 'Format email kerja tidak valid atau domain tidak ditemukan.',
            'work_email.unique'          => 'Email kerja ini sudah terdaftar.',
            'password.min'               => 'Password minimal 6 karakter.',
        ]);

        $verificationToken = Str::random(64);

        $user = User::create([
            'employee_id'               => $request->filled('employee_id') ? trim((string) $request->employee_id) : null,
            'full_name'                 => $request->full_name,
            'personal_email'            => $request->personal_email,
            'work_email'                => $request->filled('work_email') ? trim((string) $request->work_email) : null,
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
            'is_active'                 => false, // Require HRD + admin approval
            'registration_status'       => 'pending_hrd',
            'email_verification_token'  => $verificationToken,
        ]);

        // Email verifikasi akan dikirim nanti setelah admin melakukan Approve
        // $verificationUrl = url("/api/email/verify/{$user->id}/{$verificationToken}");
        // Mail::to($user->personal_email)->send(new VerifyEmailMail($verificationUrl, $user->full_name));
        $this->notifyHrdAboutRegistration($user);

        return response()->json([
            'status'  => 'success',
            'message' => 'Registrasi berhasil. Akun Anda sedang menunggu persetujuan HRD dan Admin. Anda akan menerima email verifikasi setelah akun disetujui.',
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

        $user->refresh();
        if ($user->is_active && $user->registration_status === 'approved') {
            $user->ensureQrCode();
        }

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

        $login = trim((string) $request->input('login'));

        $user = User::where('personal_email', $login)
            ->orWhere('work_email', $login)
            ->orWhere('employee_id', $login)
            ->first();

        if (! $user || ! Hash::check($request->password, $user->password_hash)) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Kredensial tidak valid. Periksa kembali NIP / Email dan password Anda.',
            ], 401);
        }

        if (! $user->is_active) {
            $pendingMessage = match ($user->registration_status) {
                'pending_hrd' => 'Akun Anda sedang menunggu persetujuan HRD.',
                'pending_admin' => 'Akun Anda sedang menunggu persetujuan Admin.',
                default => 'Akun Anda tidak aktif. Silakan hubungi administrator.',
            };

            return response()->json([
                'status'  => 'error',
                'message' => $pendingMessage,
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

        $user->ensureQrCode();

        $user->tokens()->update([
            'revoked_reason' => 'another_login',
            'expires_at' => now(),
        ]);
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
            'user' => $this->formatUser($request->user()),
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
        $companyName = $request->query('company_name');
        $companyCategory = $this->normalizeCompanyCategory((string) $request->query('company_category', ''));
        $companyColumns = $this->companyFilterColumns($companyCategory);

        $users = User::when($request->department, fn($q) => $q->where('department', $request->department))
        ->when($search, fn($q) => $q->where(function($sub) use ($search) {
            $sub->where('full_name', 'like', "%{$search}%")
                ->orWhere('employee_id', 'like', "%{$search}%")
                ->orWhere('personal_email', 'like', "%{$search}%")
                ->orWhere('work_email', 'like', "%{$search}%");
        }))
        ->when($companyName, fn($q) => $q->where(function($sub) use ($companyName, $companyColumns) {
            foreach ($companyColumns as $index => $column) {
                $method = $index === 0 ? 'where' : 'orWhere';
                $sub->{$method}($column, $companyName)
                    ->orWhere($column, 'like', "%{$companyName}%");
            }
        }))
        ->orderBy('full_name')
        ->select([
            'id', 'full_name', 'employee_id', 'department', 'position',
            'jabatan', 'company', 'role', 'profile_photo', 'phone_number', 
            'personal_email', 'work_email', 'tipe_afiliasi', 'is_active',
            'registration_status', 'access_permissions'
        ])
        ->get()
        ->map(fn($u) => [
            'id'             => $u->id,
            'full_name'      => $u->full_name,
            'employee_id'    => $u->employee_id,
            'department'     => $u->department,
            'position'       => $u->position,
            'jabatan'        => $u->jabatan,
            'company'        => $u->company,
            'tipe_afiliasi'  => $u->tipe_afiliasi,
            'phone_number'   => $u->phone_number,
            'personal_email' => $u->personal_email,
            'work_email'     => $u->work_email,
            'email'          => $u->personal_email ?? $u->work_email,
            'role'           => $u->role,
            'access_permissions' => $u->resolvedAccessPermissions(),
            'is_active'      => (bool) $u->is_active,
            'registration_status' => $u->registration_status,
            'photo_url'      => $u->profile_photo ? asset('storage/' . $u->profile_photo) : null,
        ]);

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }

    // GET /api/pic-users — daftar semua user untuk pilihan PIC/Penanggung Jawab.
    public function picUsers(Request $request)
    {
        $search = $request->query('search');

        $users = User::when($search, fn($q) => $q->where(function($sub) use ($search) {
            $sub->where('full_name', 'like', "%{$search}%")
                ->orWhere('employee_id', 'like', "%{$search}%")
                ->orWhere('personal_email', 'like', "%{$search}%")
                ->orWhere('work_email', 'like', "%{$search}%")
                ->orWhere('department', 'like', "%{$search}%");
        }))
        ->orderBy('full_name')
        ->select([
            'id', 'full_name', 'employee_id', 'department', 'position',
            'jabatan', 'role', 'is_active', 'registration_status',
        ])
        ->get()
        ->map(fn($u) => [
            'id'                  => $u->id,
            'full_name'           => $u->full_name,
            'employee_id'         => $u->employee_id,
            'department'          => $u->department,
            'position'            => $u->position,
            'jabatan'             => $u->jabatan,
            'role'                => $u->role,
            'is_active'           => (bool) $u->is_active,
            'registration_status' => $u->registration_status,
        ]);

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }

    private function normalizeCompanyCategory(string $category): ?string
    {
        return match ($category) {
            'owner' => 'owner',
            'kontraktor', 'contractor' => 'kontraktor',
            'subkontraktor', 'sub contractor' => 'subkontraktor',
            default => null,
        };
    }

    private function companyFilterColumns(?string $category): array
    {
        return match ($category) {
            'owner' => ['company'],
            'kontraktor' => ['perusahaan_kontraktor'],
            'subkontraktor' => ['sub_kontraktor'],
            default => ['company', 'perusahaan_kontraktor', 'sub_kontraktor'],
        };
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

        $registrationStatuses = null;
        if ($regStatus === 'pending') {
            $registrationStatuses = $this->registrationApprovalStatusesFor($request->user(), 'pending');
        }

        $users = User::when($search, function ($q) use ($search) {
            $q->where(function ($sub) use ($search) {
                $sub->where('full_name', 'like', "%{$search}%")
                    ->orWhere('employee_id', 'like', "%{$search}%")
                    ->orWhere('personal_email', 'like', "%{$search}%")
                    ->orWhere('work_email', 'like', "%{$search}%");
            });
        })
        ->when($role, fn($q) => $q->where('role', $role))
        ->when($department, fn($q) => $q->where('department', $department))
        ->when($isActive !== null, fn($q) => $q->where('is_active', filter_var($isActive, FILTER_VALIDATE_BOOLEAN)))
        ->when($registrationStatuses !== null, fn($q) => $q->whereIn('registration_status', $registrationStatuses))
        ->when($regStatus && $registrationStatuses === null, fn($q) => $q->where('registration_status', $regStatus))
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
            'employee_id'    => 'nullable|string|min:5|max:20|unique:users,employee_id',
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
            'access_permissions' => 'nullable|array',
            'access_permissions.*' => 'boolean',
            'password'       => 'required|string|min:6',
            'is_active'      => 'boolean',
        ]);

        $isActive = $request->has('is_active') ? $request->boolean('is_active') : true;

        $user = User::create([
            'employee_id'       => $request->filled('employee_id') ? trim((string) $request->employee_id) : null,
            'full_name'      => $request->full_name,
            'personal_email' => $request->personal_email,
            'work_email'     => $request->filled('work_email') ? trim((string) $request->work_email) : null,
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
            'access_permissions' => User::normalizeAccessPermissions($request->input('access_permissions'), $request->role),
            'password_hash'  => Hash::make($request->password),
            'is_active'      => $isActive,
            'registration_status' => $isActive ? 'approved' : 'pending_hrd',
            'email_verified_at' => now(),
        ]);

        if ($user->is_active && $user->email_verified_at) {
            $user->ensureQrCode();
        }

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
            'employee_id'    => 'nullable|string|min:5|max:20|unique:users,employee_id,' . $user->id,
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
            'access_permissions' => 'nullable|array',
            'access_permissions.*' => 'boolean',
            'password'       => 'nullable|string|min:6',
            'is_active'      => 'boolean',
        ]);

        $data = $request->except(['password', 'profile_photo', 'access_permissions']);
        if ($request->has('access_permissions')) {
            $data['access_permissions'] = User::normalizeAccessPermissions($request->input('access_permissions'), $request->role);
        }
        if ($request->has('employee_id')) {
            $data['employee_id'] = $request->filled('employee_id') ? trim((string) $request->employee_id) : null;
        }
        if ($request->has('work_email')) {
            $data['work_email'] = $request->filled('work_email') ? trim((string) $request->work_email) : null;
        }
        if ($request->filled('password')) {
            $data['password_hash'] = Hash::make($request->password);
        }

        $user->update($data);
        if ($user->is_active && $user->email_verified_at) {
            $user->ensureQrCode();
        }

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

    // PUT /api/admin/licenses/{id}/verify
    public function adminVerifyLicense(Request $request, string $id)
    {
        if ($request->boolean('is_verified', true)) {
            return $this->adminApproveLicense($request, $id);
        }

        $license = UserLicense::findOrFail($id);
        $reason = trim((string) $request->input('reason', 'Ditolak melalui endpoint verifikasi lisensi.'));
        if ($reason === '') {
            $reason = 'Ditolak melalui endpoint verifikasi lisensi.';
        }
        if (!in_array($license->approval_status, ['pending', 'pending_changes'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya lisensi dengan status pending atau menunggu perubahan yang dapat ditolak.',
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
        if (!in_array($cert->approval_status, ['pending', 'pending_changes'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya sertifikasi dengan status pending atau menunggu perubahan yang dapat ditolak.',
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
    public function adminApproveLicense(Request $request, string $id)
    {
        $license = UserLicense::with('user')->findOrFail($id);

        if (!in_array($license->approval_status, ['pending', 'pending_changes'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya lisensi dengan status pending atau menunggu perubahan yang dapat disetujui.',
            ], 422);
        }

        $rules = [
            'obtained_at' => 'nullable|date',
            'expired_at' => 'nullable|date|after_or_equal:obtained_at',
        ];

        if ($license->license_type === 'mine_permit') {
            $rules['obtained_at'] = 'required|date';
            $rules['expired_at'] = 'required|date|after_or_equal:obtained_at';
        }

        $validated = $request->validate($rules);

        $updateData = [
            'approval_status' => 'approved',
            'is_verified' => true,
            'rejection_reason' => null,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ];

        if (array_key_exists('obtained_at', $validated)) {
            $updateData['obtained_at'] = $validated['obtained_at'];
        }

        if (array_key_exists('expired_at', $validated)) {
            $updateData['expired_at'] = $validated['expired_at'];
        }

        $license->update($updateData);

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

        if (!in_array($license->approval_status, ['pending', 'pending_changes'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya lisensi dengan status pending atau menunggu perubahan yang dapat ditolak.',
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

        if (!in_array($certification->approval_status, ['pending', 'pending_changes'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya sertifikasi dengan status pending atau menunggu perubahan yang dapat disetujui.',
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

        if (!in_array($certification->approval_status, ['pending', 'pending_changes'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya sertifikasi dengan status pending atau menunggu perubahan yang dapat ditolak.',
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

    public function registrationApprovalsIndex(Request $request)
    {
        $statuses = $this->registrationApprovalStatusesFor($request->user(), $request->query('status'));

        $users = User::with(['reviewer', 'hrdReviewer', 'adminReviewer'])
            ->whereIn('registration_status', $statuses)
            ->latest('created_at')
            ->paginate($request->query('per_page', 10));

        return response()->json([
            'status' => 'success',
            'data'   => $users,
        ]);
    }

    public function adminApprove(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        $registrationStatus = $this->normalizeRegistrationStatus($user->registration_status);

        if ($registrationStatus === 'pending_hrd') {
            if (! $this->canReviewHrdRegistration($request->user())) {
                return response()->json([
                    'status'  => 'error',
                    'message' => 'Hanya HRD atau Superadmin yang dapat menyetujui tahap HRD.',
                ], 403);
            }

            $now = now();
            $user->update([
                'is_active' => false,
                'registration_status' => 'pending_admin',
                'rejection_reason' => null,
                'hrd_reviewed_by' => Auth::id(),
                'hrd_reviewed_at' => $now,
                'reviewed_by' => Auth::id(),
                'reviewed_at' => $now,
            ]);

            ReadStatus::where('item_type', 'approval_registration')
                ->where('item_id', $user->id)
                ->delete();

            $this->notifyAdminsAboutRegistration($user->fresh());

            return response()->json([
                'status'  => 'success',
                'message' => 'Pendaftaran berhasil disetujui HRD dan diteruskan ke Admin.',
                'data'    => $user->fresh(),
            ]);
        }

        if ($registrationStatus !== 'pending_admin') {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya pendaftaran pending HRD atau pending Admin yang dapat disetujui.',
            ], 422);
        }

        if (! $this->canReviewAdminRegistration($request->user())) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya Admin atau Superadmin yang dapat menyetujui tahap Admin.',
            ], 403);
        }

        $now = now();
        $user->update([
            'is_active' => true,
            'registration_status' => 'approved',
            'rejection_reason' => null,
            'admin_reviewed_by' => Auth::id(),
            'admin_reviewed_at' => $now,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => $now,
        ]);

        $user->refresh();
        if ($user->email_verified_at) {
            $user->ensureQrCode();
        }

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
        $request->validate([
            'reason' => 'required|string|max:2000',
        ]);

        $user = User::findOrFail($id);
        $registrationStatus = $this->normalizeRegistrationStatus($user->registration_status);

        if (! in_array($registrationStatus, ['pending_hrd', 'pending_admin'])) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya pendaftaran pending HRD atau pending Admin yang dapat ditolak.',
            ], 422);
        }

        if ($registrationStatus === 'pending_hrd' && ! $this->canReviewHrdRegistration($request->user())) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya HRD atau Superadmin yang dapat menolak tahap HRD.',
            ], 403);
        }

        if ($registrationStatus === 'pending_admin' && ! $this->canReviewAdminRegistration($request->user())) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Hanya Admin atau Superadmin yang dapat menolak tahap Admin.',
            ], 403);
        }

        $reason = trim((string) $request->input('reason'));
        $stage = $registrationStatus === 'pending_hrd' ? 'hrd' : 'admin';
        
        // Create registration log entry
        RegistrationLog::create([
            'full_name'        => $user->full_name,
            'employee_id'      => $user->employee_id,
            'personal_email'   => $user->personal_email,
            'phone_number'     => $user->phone_number,
            'company'          => $user->company,
            'department'       => $user->department,
            'rejection_reason' => $reason,
            'registration_status' => $registrationStatus,
            'rejection_stage'  => $stage,
            'rejected_by'      => Auth::id(),
            'rejected_at'      => now(),
        ]);

        // Kirim email penolakan SEBELUM di-delete (agar data email masih ada)
        Mail::to($user->personal_email)->send(new RegistrationRejectedMail($user->full_name, $reason, strtoupper($stage)));

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
        $logs = RegistrationLog::with('rejectedBy')
            ->orderBy('rejected_at', 'desc')
            ->paginate($request->query('per_page', 10));

        return response()->json([
            'status'  => 'success',
            'message' => 'Registration logs retrieved successfully',
            'data'    => $logs,
        ]);
    }

    private function normalizeRegistrationStatus(?string $status): string
    {
        return $status === 'pending' || $status === null || trim($status) === ''
            ? 'pending_hrd'
            : trim($status);
    }

    private function canReviewHrdRegistration(?User $user): bool
    {
        return $user !== null && ($user->role === 'superadmin' || $user->isHrdReviewer());
    }

    private function canReviewAdminRegistration(?User $user): bool
    {
        return $user !== null && in_array($user->role, ['admin', 'superadmin'], true);
    }

    private function registrationApprovalStatusesFor(?User $user, ?string $requestedStatus = null): array
    {
        $statuses = [];

        if ($this->canReviewHrdRegistration($user)) {
            $statuses[] = 'pending_hrd';
        }

        if ($this->canReviewAdminRegistration($user)) {
            $statuses[] = 'pending_admin';
        }

        $rawRequestedStatus = $requestedStatus ? trim((string) $requestedStatus) : null;
        if ($rawRequestedStatus === 'pending') {
            return $statuses;
        }

        $requestedStatus = $rawRequestedStatus ? $this->normalizeRegistrationStatus($rawRequestedStatus) : null;
        if ($requestedStatus === 'pending_hrd' || $requestedStatus === 'pending_admin') {
            return in_array($requestedStatus, $statuses, true) ? [$requestedStatus] : [];
        }

        return $statuses;
    }

    private function notifyAdminsAboutRegistration(User $applicant): void
    {
        $admins = User::whereIn('role', ['admin', 'superadmin'])
            ->where('is_active', true)
            ->whereNotNull('email_verified_at')
            ->get();

        foreach ($admins as $admin) {
            try {
                $this->notificationService->createNotification(
                    $admin,
                    'registration_pending_admin',
                    'Pendaftaran Menunggu Admin',
                    "{$applicant->full_name} telah disetujui HRD dan menunggu persetujuan Admin.",
                    ['type' => 'auth', 'registration_id' => $applicant->id]
                );
            } catch (\Exception $e) {
                Log::error('Gagal mengirim notifikasi pending admin registration: ' . $e->getMessage());
            }
        }
    }

    private function notifyHrdAboutRegistration(User $applicant): void
    {
        $reviewers = User::hrdReviewers();

        if ($reviewers->isEmpty()) {
            $reviewers = User::where('role', 'superadmin')
                ->where('is_active', true)
                ->whereNotNull('email_verified_at')
                ->get();
        }

        foreach ($reviewers as $reviewer) {
            try {
                $this->notificationService->createNotification(
                    $reviewer,
                    'registration_pending_hrd',
                    'Pendaftaran Menunggu HRD',
                    "{$applicant->full_name} mengajukan pendaftaran akun dan menunggu persetujuan HRD.",
                    ['type' => 'auth', 'registration_id' => $applicant->id]
                );
            } catch (\Exception $e) {
                Log::error('Gagal mengirim notifikasi pending HRD registration: ' . $e->getMessage());
            }
        }
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
                ? (filter_var($user->profile_photo, FILTER_VALIDATE_URL)
                    ? $user->profile_photo
                    : asset('storage/' . $user->profile_photo))
                : null,
            'role'           => $user->role,
            'access_permissions' => $user->resolvedAccessPermissions(),
            'is_active'      => $user->is_active,
            'registration_status' => $user->registration_status,
            'is_hrd_reviewer' => $user->isHrdReviewer(),
        ];
    }
}
