<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Department extends Model
{
    protected $fillable = ['name', 'is_hrd'];

    protected $casts = [
        'is_hrd' => 'boolean',
    ];
}
