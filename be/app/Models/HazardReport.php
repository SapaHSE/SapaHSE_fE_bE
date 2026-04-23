<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;

class HazardReport extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'hazard_reports';

    protected $fillable = [
        'user_id',
        'ticket_number',
        'title',
        'description',
        'status',
        'sub_status',
        'location',
        'pelapor_location',
        'kejadian_location',
        'image_url',
        'severity',
        'pic_department',
        'pelaku_pelanggaran',
        'reported_department',
        'hazard_category',
        'hazard_subcategory',
        'suggestion',
        'is_public',
        'due_date',        
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function logs()
    {
        return $this->morphMany(ReportLog::class, 'reportable')->orderBy('created_at', 'desc');
    }

    public function isReadBy(?string $userId): bool
    {
        if (!$userId) return false;
        return ReadStatus::where('user_id', $userId)
            ->where('item_id', $this->id)
            ->where('item_type', 'hazard_report')
            ->exists();
    }

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($model) {
            if (empty($model->due_date)) {
                $days = match ($model->severity) {
                    'high'   => 3,
                    'medium' => 7,
                    'low'    => 14,
                    default  => 7,
                };
                $model->due_date = now()->addDays($days);
            }
            
            if (empty($model->ticket_number)) {
                DB::transaction(function () use ($model) {
                    // Gunakan company dari model, fallback ke company user, lalu 'UNK'
                    $company = strtoupper(trim($model->company ?? ''));
                    if (empty($company) && $model->user_id) {
                        $user = \App\Models\User::find($model->user_id);
                        $company = strtoupper(trim($user->company ?? ''));
                    }
                    $company = $company ?: 'UNK';

                    // Generate Acronym (e.g. Bukit Baiduri Energi -> BBE)
                    $cleanName = preg_replace('/\b(PT|CV|INC|LTD)\b\.?/i', '', $company);
                    $words = explode(' ', trim($cleanName));
                    $acronym = '';
                    foreach ($words as $w) {
                        if (!empty($w)) $acronym .= strtoupper($w[0]);
                    }
                    $acronym = $acronym ?: 'UNK';

                    $year = date('Y');
                    $prefix = "{$acronym}-HZR-HSE-{$year}-";

                    // Lock baris terakhir agar tidak ada duplicate sequence (concurrent safe)
                    $lastSeq = (int) static::where('ticket_number', 'like', "{$prefix}%")
                        ->lockForUpdate()
                        ->selectRaw('MAX(CAST(SUBSTRING_INDEX(ticket_number, \'-\', -1) AS UNSIGNED)) as last_seq')
                        ->value('last_seq');

                    $nextSeq = $lastSeq + 1;
                    $model->ticket_number = $prefix . str_pad($nextSeq, 6, '0', STR_PAD_LEFT);
                });
            }
        });
    }
}