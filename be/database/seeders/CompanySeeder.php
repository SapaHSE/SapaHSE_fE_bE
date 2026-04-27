<?php

namespace Database\Seeders;

use App\Models\Company;
use Illuminate\Database\Seeder;

class CompanySeeder extends Seeder
{
    public function run(): void
    {
        $companies = [
            // Owners
            [
                'name' => 'PT Bukit Baiduri Energi',
                'code' => 'BBE',
                'category' => 'owner',
                'is_active' => true,
            ],
            [
                'name' => 'PT Khotai Makmur Insan Abadi',
                'code' => 'KMA',
                'category' => 'owner',
                'is_active' => true,
            ],
            // Kontraktor
            [
                'name' => 'PT Pama Persada Nusantara',
                'code' => 'PAMA',
                'category' => 'kontraktor',
                'is_active' => true,
            ],
            [
                'name' => 'PT Saptaindra Sejati',
                'code' => 'SIS',
                'category' => 'kontraktor',
                'is_active' => true,
            ],
            [
                'name' => 'PT Bukit Makmur Mandiri Utama',
                'code' => 'BUMA',
                'category' => 'kontraktor',
                'is_active' => true,
            ],
            [
                'name' => 'PT Thiess Contractors Indonesia',
                'code' => 'THIESS',
                'category' => 'kontraktor',
                'is_active' => true,
            ],
            // Subkontraktor
            [
                'name' => 'CV Karya Makmur',
                'code' => 'KM',
                'category' => 'subkontraktor',
                'is_active' => true,
            ],
            [
                'name' => 'PT United Tractors Tbk',
                'code' => 'UT',
                'category' => 'subkontraktor',
                'is_active' => true,
            ],
            [
                'name' => 'PT Trakindo Utama',
                'code' => 'TRAKINDO',
                'category' => 'subkontraktor',
                'is_active' => true,
            ],
            [
                'name' => 'PT Hexindo Adiperkasa',
                'code' => 'HEXINDO',
                'category' => 'subkontraktor',
                'is_active' => true,
            ],
        ];

        foreach ($companies as $company) {
            Company::updateOrCreate(
                ['name' => $company['name']],
                $company
            );
        }
    }
}