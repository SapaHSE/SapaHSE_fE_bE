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
        'nik',
        'employee_id',
        'full_name',
        'email',
        'phone_number',
        'position',
        'department',
        'password',
        'profile_photo',
        'is_active',
        'role',
        'fcm_token',
        'last_activity_at',
        'last_notification_sent_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'last_activity_at' => 'datetime',
            'last_notification_sent_at' => 'datetime',
        ];
    }

    public function reports()
    {
        return $this->hasMany(Report::class, 'user_id');
    }

    public function inspections()
    {
        return $this->hasMany(Inspection::class, 'user_id');
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
}