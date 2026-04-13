<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ReadStatus extends Model
{
    use HasUuids;

    protected $table = 'read_status';
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'item_id',
        'item_type',
        'read_at',
    ];

    protected function casts(): array
    {
        return ['read_at' => 'datetime'];
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
