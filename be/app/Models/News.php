<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class News extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'created_by',
        'title',
        'excerpt',
        'content',
        'category',
        'author_name',
        'image_url',
        'is_featured',
        'is_active',
        'publish_date',
        'published_notified',
    ];

    protected function casts(): array
    {
        return [
            'is_featured'        => 'boolean',
            'is_active'          => 'boolean',
            'publish_date'       => 'date',
            'published_notified' => 'boolean',
        ];
    }

    public function scopeActive($q) { return $q->where('is_active', true); }
    public function scopeFeatured($q) { return $q->where('is_featured', true); }

    // Publicly visible: is_active AND publish_date in the past or today.
    public function scopePublished($q)
    {
        return $q->where('is_active', true)
                 ->whereDate('publish_date', '<=', now()->toDateString());
    }

    // Scheduled-only: is_active AND publish_date in the future.
    public function scopeScheduled($q)
    {
        return $q->where('is_active', true)
                 ->whereDate('publish_date', '>', now()->toDateString());
    }

    public function isScheduled(): bool
    {
        return $this->publish_date
            && $this->publish_date->isAfter(now()->startOfDay());
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}