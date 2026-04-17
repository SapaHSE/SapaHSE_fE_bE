<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class ReportLog extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'reportable_id',
        'reportable_type',
        'user_id',
        'tagged_user_id',
        'status',
        'sub_status',
        'message',
        'image_url',
    ];

    public function reportable(): MorphTo
    {
        return $this->morphTo();
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function taggedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'tagged_user_id');
    }
}