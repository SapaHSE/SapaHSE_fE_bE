<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class HazardCategory extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'code'];

    public function subcategories()
    {
        return $this->hasMany(HazardSubcategory::class, 'category_id');
    }
}