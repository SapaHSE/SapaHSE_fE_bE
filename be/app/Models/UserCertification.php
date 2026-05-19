<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class UserCertification extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'name',
        'certification_number',
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
        'expired_at'  => 'date',
        'is_verified' => 'boolean',
        'reviewed_at' => 'datetime',
        'submitted_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
