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
        'expired_at',
        'status',
    ];

    protected $casts = [
        'expired_at' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
