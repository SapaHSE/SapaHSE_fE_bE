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
        'issuer',
        'year',
        'status',
        'file_path',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
