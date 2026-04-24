<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class HazardSubcategory extends Model
{
    use HasFactory;

    protected $fillable = ['category_id', 'name', 'abbreviation', 'description', 'is_active'];

    public function category()
    {
        return $this->belongsTo(HazardCategory::class, 'category_id');
    }
}