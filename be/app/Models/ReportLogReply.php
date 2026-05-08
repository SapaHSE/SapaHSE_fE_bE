<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ReportLogReply extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'report_log_id',
        'parent_reply_id',
        'user_id',
        'message',
        'attachment_url',
        'attachment_urls',
    ];

    protected $casts = [
        'attachment_urls' => 'array',
    ];

    public function reportLog(): BelongsTo
    {
        return $this->belongsTo(ReportLog::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function parentReply(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_reply_id');
    }

    public function childReplies(): HasMany
    {
        return $this->hasMany(self::class, 'parent_reply_id');
    }
}
