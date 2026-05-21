<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Area extends Model
{
    use HasFactory;

    protected $fillable = ['company_id', 'name', 'code', 'pic_user_id', 'pic_user_ids', 'is_active'];

    protected function casts(): array
    {
        return [
            'pic_user_ids' => 'array',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Area belongs to a company.
     */
    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Area is managed by a user as PIC.
     */
    public function picUser()
    {
        return $this->belongsTo(User::class, 'pic_user_id');
    }

    /**
     * Scope: filter areas by company_id.
     */
    public function scopeForCompany($query, int $companyId)
    {
        return $query->where('company_id', $companyId);
    }
}
