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
        'location',
        'date_of_violation',
        'status',
        'sanction',
    ];

    protected function casts(): array
    {
        return [
            'date_of_violation' => 'date',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}