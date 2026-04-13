<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ChecklistItem extends Model
{
    use HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'report_id',
        'label',
        'is_checked',
        'sort_order',
    ];

    protected function casts(): array
    {
        return ['is_checked' => 'boolean'];
    }

    public function report()
    {
        return $this->belongsTo(Report::class, 'report_id');
    }
}
