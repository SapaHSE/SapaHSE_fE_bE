<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class HazardReport extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'hazard_reports';

    protected $fillable = [
        'user_id',
        'ticket_number',
        'title',
        'description',
        'status',
        'sub_status',
        'location',
        'image_url',
        'severity',
        'name_pja',
        'reported_department',
        'hazard_category',
        'hazard_subcategory',
        'suggestion',
        'is_public',        
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function logs()
    {
        return $this->morphMany(ReportLog::class, 'reportable')->orderBy('created_at', 'desc');
    }

    public function isReadBy(?string $userId): bool
    {
        if (!$userId) return false;
        return ReadStatus::where('user_id', $userId)
            ->where('item_id', $this->id)
            ->where('item_type', 'hazard_report')
            ->exists();
    }

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($model) {
            if (empty($model->ticket_number)) {
                $dateStr = date('Ymd');
                $randomStr = strtoupper(Str::random(4));
                $model->ticket_number = "TKT-HZR-{$dateStr}-{$randomStr}";
            }
        });
    }
}