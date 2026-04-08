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
        'inspection_id',
        'label',
        'is_checked',
        'sort_order'
    ];


    protected function casts(): array
    {
        return ['is_checked' => 'boolean'];
    }

    public function inspection()
    {
        return $this->belongsTo(Inspection::class, 'inspection_id');
    }
}
