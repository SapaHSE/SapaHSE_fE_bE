<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class UserLicense extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'name',
        'license_number',
        'license_type',
        'vehicle_equipment',
        'sim_type',
        'sim_indonesia_type',
        'issuer',
        'obtained_at',
        'expired_at',
        'status',
        'is_verified',
        'approval_status',
        'rejection_reason',
        'reviewed_by',
        'reviewed_at',
        'submitted_at',
        'file_path',
    ];

    protected $casts = [
        'obtained_at' => 'date',
        'expired_at' => 'date',
        'is_verified' => 'boolean',
        'reviewed_at' => 'datetime',
        'submitted_at' => 'datetime',
    ];

    protected static function boot()
    {
        parent::boot();

        static::saving(function ($model) {
            if ($model->expired_at) {
                if ($model->expired_at->isPast()) {
                    $model->status = 'expired';
                } elseif ($model->status === 'expired') {
                    // Re-activate if date is updated to future
                    $model->status = 'active';
                }
            }
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function canBeRenewedNow(?Carbon $now = null): bool
    {
        if (! $this->expired_at) {
            return true;
        }
        $now ??= Carbon::now();
        return ! Carbon::parse($this->expired_at)->copy()->subMonth()->isAfter($now);
    }

    public static function renewalBlockedMessage(): string
    {
        return 'Perpanjangan belum bisa dilakukan karena masih berlaku. '
            . 'Ajukan paling cepat 1 bulan sebelum habis masa berlaku';
    }
}
