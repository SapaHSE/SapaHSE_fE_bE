<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserViolation extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'user_violations';

    protected $fillable = [
        'user_id',
        'title',
        'description',
        'location',
        'date_of_violation',
        'expired_at',
        'status',
        'sanction',
        'file_url',
    ];

    protected function casts(): array
    {
        return [
            'date_of_violation' => 'date',
            'expired_at' => 'date',
        ];
    }

    protected static function boot()
    {
        parent::boot();

        static::saving(function ($model) {
            if ($model->expired_at) {
                if ($model->expired_at->isPast()) {
                    $model->status = 'Selesai';
                } elseif ($model->status === 'Selesai') {
                    $model->status = 'Aktif';
                }
            }
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
