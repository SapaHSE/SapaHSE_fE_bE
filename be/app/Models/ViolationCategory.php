<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ViolationCategory extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'code'];

    public function subcategories()
    {
        return $this->hasMany(ViolationSubcategory::class, 'category_id');
    }
}
