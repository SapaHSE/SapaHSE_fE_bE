<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class UserMedical extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'title',
        'patient_name',
        'checkup_date',
        'blood_type',
        'height',
        'weight',
        'blood_pressure',
        'allergies',
        'result',
        'next_checkup_date',
        'doctor_name',
        'doctor_contact',
        'facility_name',
        'facility_contact',
        'doctor_notes',
        'checklist_items',
    ];

    protected $casts = [
        'checkup_date'     => 'date',
        'next_checkup_date'=> 'date',
        'checklist_items'  => 'array',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}