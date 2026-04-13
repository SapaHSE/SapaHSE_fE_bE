<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'body',
        'data',
        'status',
        'pushed_at',
        'emailed_at',
        'read_at',
    ];

    protected $casts = [
        'data' => 'array',
        'pushed_at' => 'datetime',
        'emailed_at' => 'datetime',
        'read_at' => 'datetime',
    ];

    // Relasi ke User
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scope: notification yang belum dikirim push
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    // Scope: notification yang sudah dikirim push tapi belum email
    public function scopeSentPush($query)
    {
        return $query->where('status', 'sent_push');
    }

    // Cek apakah sudah lewat 3 hari sejak push notification
    public function shouldEmailAfterThreeDays(): bool
    {
        if (!$this->pushed_at) {
            return false;
        }

        return now()->diffInDays($this->pushed_at) >= 3;
    }
}
