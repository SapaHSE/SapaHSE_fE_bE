<?php

namespace Database\Seeders;

use App\Models\ViolationCategory;
use App\Models\ViolationSubcategory;
use Illuminate\Database\Seeder;

class ViolationCategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            [
                'name' => 'Keselamatan Kerja',
                'code' => 'K3',
                'subcategories' => [
                    'Tidak Pakai APD',
                    'Alat Rusak/Layak Pakai',
                    'Area Kerja Tidak Aman',
                ],
            ],
            [
                'name' => 'Kedisiplinan',
                'code' => 'DSP',
                'subcategories' => [
                    'Terlambat/Izin Tidak Sah',
                    'Tidak Patuh Prosedur',
                    'Meninggalkan Tugas',
                ],
            ],
            [
                'name' => 'Operasional',
                'code' => 'OPS',
                'subcategories' => [
                    'SOP Dilanggar',
                    'Dokumen Tidak Lengkap',
                    'Operasi Tanpa Izin',
                ],
            ],
            [
                'name' => 'Lingkungan',
                'code' => 'LHK',
                'subcategories' => [
                    'Buang Limbah Sembarangan',
                    'Pencemaran Lingkungan',
                    'Kebersihan Area',
                ],
            ],
            [
                'name' => 'Lalu Lintas',
                'code' => 'LL',
                'subcategories' => [
                    'Parkir Sembarangan',
                    'Berkendara Berbahaya',
                    'Tidak Punya SIM',
                ],
            ],
        ];

        foreach ($categories as $item) {
            $category = ViolationCategory::updateOrCreate(
                ['code' => $item['code']],
                ['name' => $item['name']]
            );

            foreach ($item['subcategories'] as $subcategory) {
                ViolationSubcategory::updateOrCreate(
                    [
                        'category_id' => $category->id,
                        'name' => $subcategory,
                    ],
                    ['is_active' => true]
                );
            }
        }
    }
}
