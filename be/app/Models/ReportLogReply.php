<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReportLogReply extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'report_log_id',
        'user_id',
        'message',
        'attachment_url',
    ];

    public function reportLog(): BelongsTo
    {
        return $this->belongsTo(ReportLog::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
