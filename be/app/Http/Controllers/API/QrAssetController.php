<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\QrAsset;
use App\Models\User;
use Illuminate\Http\Request;

class QrAssetController extends Controller
{
    // GET /api/qr-assets
    public function index()
    {
        $assets = QrAsset::latest()->get();

        return response()->json([
            'status' => 'success',
            'data'   => $assets->map(fn($a) => $this->formatAsset($a)),
        ]);
    }

    // GET /api/qr-assets/scan?qr_code=BBE-APAR-2024-001234
    public function scan(Request $request)
    {
        $request->validate([
            'qr_code' => 'required|string',
        ]);

        $asset = QrAsset::where('qr_code', $this->normalizeQrCode($request->qr_code))->first();

        if (! $asset) {
            return response()->json([
                'status'  => 'error',
                'message' => 'QR Code not found. Asset is not registered in the system.',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatAsset($asset),
        ]);
    }

    // GET /api/qr/scan?qr_code=SAPA-HSE-USER-...
    public function scanAny(Request $request)
    {
        $request->validate([
            'qr_code' => 'required|string',
        ]);

        $qrCode = $this->normalizeQrCode($request->qr_code);

        $user = User::where('qr_code', $qrCode)
            ->where('is_active', true)
            ->whereNotNull('email_verified_at')
            ->first();

        if ($user) {
            return response()->json([
                'status' => 'success',
                'type'   => 'user',
                'data'   => $this->formatUser($user),
            ]);
        }

        $asset = QrAsset::where('qr_code', $qrCode)->first();

        if ($asset) {
            return response()->json([
                'status' => 'success',
                'type'   => 'asset',
                'data'   => $this->formatAsset($asset),
            ]);
        }

        return response()->json([
            'status'  => 'error',
            'message' => 'QR Code tidak ditemukan atau belum aktif.',
        ], 404);
    }

    // GET /api/qr/me
    public function myQr(Request $request)
    {
        /** @var \App\Models\User|null $user */
        $user = $request->user();

        if (! $user || ! $user->is_active || ! $user->email_verified_at) {
            return response()->json([
                'status'  => 'error',
                'message' => 'QR profil hanya tersedia untuk akun aktif dan email terverifikasi.',
            ], 409);
        }

        $user->ensureQrCode();

        return response()->json([
            'status' => 'success',
            'data'   => [
                'qr_code' => $user->qr_code,
                'user'    => $this->formatUser($user),
            ],
        ]);
    }

    private function formatAsset(QrAsset $asset): array
    {
        return [
            'target'       => 'asset',
            'id'           => $asset->id,
            'qr_code'      => $asset->qr_code,
            'asset_name'   => $asset->asset_name,
            'asset_type'   => $asset->asset_type,
            'location'     => $asset->location,
            'condition'    => $asset->condition,
            'last_checked' => $asset->last_checked?->format('d F Y'),
            'next_check'   => $asset->next_check?->format('d F Y'),
            'notes'        => $asset->notes,
        ];
    }

    private function formatUser(User $user): array
    {
        return [
            'target'         => 'user',
            'id'             => $user->id,
            'qr_code'        => $user->qr_code,
            'employee_id'    => $user->employee_id,
            'full_name'      => $user->full_name,
            'personal_email' => $user->personal_email,
            'work_email'     => $user->work_email,
            'phone_number'   => $user->phone_number,
            'position'       => $user->position,
            'jabatan'        => $user->jabatan,
            'department'     => $user->department,
            'company'        => $user->company,
            'tipe_afiliasi'  => $user->tipe_afiliasi,
            'perusahaan_kontraktor' => $user->perusahaan_kontraktor,
            'sub_kontraktor' => $user->sub_kontraktor,
            'profile_photo'  => $user->profile_photo
                ? (filter_var($user->profile_photo, FILTER_VALIDATE_URL)
                    ? $user->profile_photo
                    : asset('storage/' . $user->profile_photo))
                : null,
            'role'           => $user->role,
            'is_active'      => $user->is_active,
        ];
    }

    private function normalizeQrCode(string $value): string
    {
        $value = trim($value);

        $decoded = json_decode($value, true);
        if (is_array($decoded)) {
            $value = (string) ($decoded['qr_code'] ?? $decoded['code'] ?? $value);
        }

        $parts = parse_url($value);
        if (is_array($parts) && isset($parts['query'])) {
            parse_str($parts['query'], $query);
            if (! empty($query['qr_code'])) {
                $value = (string) $query['qr_code'];
            }
        }

        return strtoupper(trim($value));
    }
}
