<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * @property string $id
 * @property string|null $employee_id
 * @property string $full_name
 * @property string $personal_email
 * @property string|null $work_email
 * @property string|null $phone_number
 * @property string|null $position
 * @property string|null $jabatan
 * @property string|null $department
 * @property string|null $company
 * @property string|null $address
 * @property string|null $tipe_afiliasi
 * @property string|null $perusahaan_kontraktor
 * @property string|null $sub_kontraktor
 * @property string|null $simper
 * @property string $password_hash
 * @property string|null $profile_photo
 * @property bool $is_active
 * @property string $role
 * @property string $registration_status
 * @property string|null $rejection_reason
 * @property string|null $email_verification_token
 * @property string|null $qr_code
 * @property string|null $fcm_token
 * @property string|null $remember_token
 * @property \Illuminate\Support\Carbon|null $email_verified_at
 * @property \Illuminate\Support\Carbon|null $last_activity_at
 * @property \Illuminate\Support\Carbon|null $last_notification_sent_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 */
class User extends Authenticatable
{
    use HasFactory, Notifiable, HasApiTokens, HasUuids;

    protected $fillable = [
        'employee_id',
        'full_name',
        'personal_email',
        'work_email',
        'email_verified_at',
        'email_verification_token',
        'qr_code',
        'phone_number',
        'position',
        'jabatan',
        'department',
        'company',
        'address',
        'tipe_afiliasi',
        'perusahaan_kontraktor',
        'sub_kontraktor',
        'simper',
        'password_hash',
        'profile_photo',
        'is_active',
        'role',
        'registration_status',
        'rejection_reason',
        'fcm_token',
        'last_activity_at',
        'last_notification_sent_at',
    ];

    protected $hidden = [
        'password_hash',
        'email_verification_token',
        'remember_token',
    ];

    // Map Laravel Auth ke kolom password_hash
    public function getAuthPassword(): string
    {
        return $this->password_hash;
    }

    protected function casts(): array
    {
        return [
            'is_active'                 => 'boolean',
            'email_verified_at'         => 'datetime',
            'last_activity_at'          => 'datetime',
            'last_notification_sent_at' => 'datetime',
        ];
    }

    public function ensureQrCode(): ?string
    {
        $employeeId = trim((string) $this->employee_id);
        if ($employeeId === '') {
            if ($this->qr_code !== null) {
                $this->forceFill(['qr_code' => null])->save();
            }

            return null;
        }

        $employeeQrCode = 'SapaHSE-USER-' . strtoupper($employeeId);

        if ($this->qr_code === $employeeQrCode) {
            return $this->qr_code;
        }

        $this->forceFill(['qr_code' => $employeeQrCode])->save();

        return $employeeQrCode;
    }

    public function resolvedCompany(): ?Company
    {
        $affiliation = strtolower(trim((string) $this->tipe_afiliasi));
        $affiliation = str_replace(['-', ' ', '.'], '', $affiliation);

        $candidates = match (true) {
            str_contains($affiliation, 'sub') => [
                ['name' => $this->sub_kontraktor, 'category' => 'subkontraktor'],
                ['name' => $this->perusahaan_kontraktor, 'category' => 'kontraktor'],
                ['name' => $this->company, 'category' => 'owner'],
            ],
            str_contains($affiliation, 'kontraktor') || str_contains($affiliation, 'contractor') => [
                ['name' => $this->perusahaan_kontraktor, 'category' => 'kontraktor'],
                ['name' => $this->company, 'category' => 'owner'],
            ],
            default => [
                ['name' => $this->company, 'category' => 'owner'],
                ['name' => $this->perusahaan_kontraktor, 'category' => 'kontraktor'],
                ['name' => $this->sub_kontraktor, 'category' => 'subkontraktor'],
            ],
        };

        foreach ($candidates as $candidate) {
            $name = trim((string) ($candidate['name'] ?? ''));
            if ($name === '') {
                continue;
            }

            $company = Company::with('kttUser')
                ->where('category', $candidate['category'])
                ->get()
                ->first(function (Company $company) use ($name) {
                    return self::normalizeCompanyLookup((string) $company->name) === self::normalizeCompanyLookup($name)
                        || self::normalizeCompanyLookup((string) $company->code) === self::normalizeCompanyLookup($name);
                });

            if ($company) {
                return $company;
            }
        }

        return null;
    }

    public function companyDetailPayload(): ?array
    {
        return $this->resolvedCompany()?->toApiArray();
    }

    public function ownerCompanyDetailPayload(): ?array
    {
        $ownerName = trim((string) $this->company);
        if ($ownerName === '') {
            return null;
        }

        $ownerCompany = Company::with('kttUser')
            ->where('category', 'owner')
            ->get()
            ->first(function (Company $company) use ($ownerName) {
                return self::normalizeCompanyLookup((string) $company->name) === self::normalizeCompanyLookup($ownerName)
                    || self::normalizeCompanyLookup((string) $company->code) === self::normalizeCompanyLookup($ownerName);
            });

        return $ownerCompany?->toApiArray();
    }

    public static function normalizeCompanyLookup(string $value): string
    {
        $normalized = strtolower(trim($value));
        $normalized = preg_replace('/[.,]/', ' ', $normalized) ?? $normalized;
        $normalized = preg_replace('/\s+/', ' ', $normalized) ?? $normalized;

        if (str_starts_with($normalized, 'pt ')) {
            $normalized = trim(substr($normalized, 3));
        }

        return $normalized;
    }

    public function hazardReports()
    {
        return $this->hasMany(HazardReport::class, 'user_id');
    }

    public function inspectionReports()
    {
        return $this->hasMany(InspectionReport::class, 'user_id');
    }

    public function announcements()
    {
        return $this->hasMany(Announcement::class, 'created_by');
    }

    public function news()
    {
        return $this->hasMany(News::class, 'created_by');
    }

    public function readStatuses()
    {
        return $this->hasMany(ReadStatus::class, 'user_id');
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class, 'user_id');
    }

    public function licenses()
    {
        return $this->hasMany(UserLicense::class, 'user_id');
    }

    public function certifications()
    {
        return $this->hasMany(UserCertification::class, 'user_id');
    }

    public function medicals()
    {
        return $this->hasMany(UserMedical::class, 'user_id');
    }

    public function violations()
    {
        return $this->hasMany(UserViolation::class, 'user_id');
    }
}
