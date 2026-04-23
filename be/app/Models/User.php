<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

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
        'phone_number',
        'position',
        'department',
        'company',
        'tipe_afiliasi',
        'perusahaan_kontraktor',
        'sub_kontraktor',
        'simper',
        'password_hash',
        'profile_photo',
        'is_active',
        'role',
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

    public function reports()
    {
        return $this->hasMany(Report::class, 'user_id');
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
}