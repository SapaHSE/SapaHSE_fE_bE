<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ViolationSubcategory extends Model
{
    use HasFactory;

    protected $fillable = ['category_id', 'name', 'abbreviation', 'description', 'is_active'];

    public function category()
    {
        return $this->belongsTo(ViolationCategory::class, 'category_id');
    }
}
