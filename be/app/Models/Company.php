<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Company extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'code',
        'logo_url',
        'ktt_signature_url',
        'company_stamp_url',
        'ktt_user_id',
        'emergency_number',
        'ert_freq',
        'radio_label',
        'radio_channel',
        'radio_frequency',
        'category',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    /**
     * A company has many areas.
     */
    public function areas()
    {
        return $this->hasMany(Area::class);
    }

    public function kttUser()
    {
        return $this->belongsTo(User::class, 'ktt_user_id');
    }

    public function toApiArray(): array
    {
        $this->loadMissing('kttUser');

        return [
            'id'               => $this->id,
            'name'             => $this->name,
            'code'             => $this->code,
            'logo_url'         => $this->logo_url,
            'ktt_signature_url'=> $this->ktt_signature_url,
            'company_stamp_url'=> $this->company_stamp_url,
            'ktt_user_id'      => $this->ktt_user_id,
            'ktt_user'         => $this->kttUser ? [
                'id'          => $this->kttUser->id,
                'full_name'   => $this->kttUser->full_name,
                'employee_id' => $this->kttUser->employee_id,
                'department'  => $this->kttUser->department,
                'position'    => $this->kttUser->position,
                'jabatan'     => $this->kttUser->jabatan,
            ] : null,
            'emergency_number' => $this->emergency_number,
            'ert_freq'         => $this->ert_freq,
            'radio_label'      => $this->radio_label,
            'radio_channel'    => $this->radio_channel,
            'radio_frequency'  => $this->radio_frequency,
            'category'         => $this->category,
            'is_active'        => $this->is_active,
            'created_at'       => $this->created_at,
            'updated_at'       => $this->updated_at,
        ];
    }
}
