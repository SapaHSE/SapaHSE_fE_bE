<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class QrAsset extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'qr_code',
        'asset_name',
        'asset_type',
        'location',
        'last_checked',
        'next_check',
        'condition',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'last_checked' => 'datetime',
            'next_check'   => 'datetime',
        ];
    }
}
