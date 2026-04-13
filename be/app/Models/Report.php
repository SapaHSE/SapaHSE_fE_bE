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
        'type',
        'title',
        'description',
        'status',
        'sub_status',
        'location',
        'image_url',
        // Hazard-only
        'severity',
        'name_pja',
        'reported_department',
        // Inspection-only
        'area',
        'notes',
        'result',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /** Checklist items — only relevant when type = inspection */
    public function checklistItems()
    {
        return $this->hasMany(ChecklistItem::class, 'report_id')->orderBy('sort_order');
    }

    public function readStatuses()
    {
        return $this->hasMany(ReadStatus::class);
    }

    public function logs()
    {
        return $this->hasMany(ReportLog::class)->orderBy('created_at', 'desc');
    }

    public function isReadBy(?string $userId): bool
    {
        if (!$userId) return false;
        return ReadStatus::where('user_id', $userId)
            ->where('item_id', $this->id)
            ->where('item_type', 'report')
            ->exists();
    }
}