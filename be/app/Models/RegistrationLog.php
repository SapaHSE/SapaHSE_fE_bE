<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class RegistrationLog extends Model
{
    use HasUuids;

    protected $fillable = [
        'full_name',
        'employee_id',
        'personal_email',
        'phone_number',
        'company',
        'department',
        'rejection_reason',
        'rejected_at',
    ];
}