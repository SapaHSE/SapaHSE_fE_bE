<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class UserMedical extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'checkup_date',
        'blood_type',
        'height',
        'weight',
        'blood_pressure',
        'allergies',
        'result',
        'next_checkup_date',
    ];

    protected $casts = [
        'checkup_date' => 'date',
        'next_checkup_date' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
