<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'title',
        'description',
        'type',
        'severity',
        'status',
        'location',
        'name_pja',
        'reported_department',
        'image_url',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function isReadBy(string $userId): bool
    {
        return ReadStatus::where('user_id', $userId)
            ->where('item_id', $this->id)
            ->where('item_type', 'report')
            ->exists();
    }
}