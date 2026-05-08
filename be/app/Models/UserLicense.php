<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class UserLicense extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'name',
        'license_number',
        'obtained_at',
        'expired_at',
        'status',
        'is_verified',
        'file_path',
    ];

    protected $casts = [
        'obtained_at' => 'date',
        'expired_at' => 'date',
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
}
