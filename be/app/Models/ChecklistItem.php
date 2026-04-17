<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ChecklistItem extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'inspection_report_id',
        'label',
        'is_checked',
        'sort_order',
    ];

    protected $casts = [
        'is_checked' => 'boolean',
        'sort_order' => 'integer',
    ];

    public function inspectionReport()
    {
        return $this->belongsTo(InspectionReport::class, 'inspection_report_id');
    }
}