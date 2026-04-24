<?php

namespace Database\Seeders;

use App\Models\HazardCategory;
use App\Models\HazardSubcategory;
use App\Models\User;
use Illuminate\Database\Seeder;

class HazardCategorySeeder extends Seeder
{
    public function run(): void
    {


        $categories = [
            [
                'name' => 'TTA (Tindakan Tidak Aman)',
                'code' => 'TTA',
                'subcategories' => [
                    [
                        'name' => 'Tidak Menggunakan APD',
                        'abbr' => 'NO-APD',
                        'desc' => 'Bekerja tanpa menggunakan alat pelindung diri yang diwajibkan.',

                    ],
                    [
                        'name' => 'Mengoperasikan Peralatan Tanpa Izin',
                        'abbr' => 'NO-AUTH',
                        'desc' => 'Mengoperasikan mesin atau kendaraan tanpa memiliki lisensi/izin.',

                    ],
                    [
                        'name' => 'Posisi/Sikap Kerja Tidak Aman',
                        'abbr' => 'BAD-POS',
                        'desc' => 'Melakukan pekerjaan dengan posisi tubuh yang berisiko cedera.',

                    ],
                    [
                        'name' => 'Bekerja di Bawah Pengaruh Alkohol/Obat',
                        'abbr' => 'INTOX',
                        'desc' => 'Bekerja dalam kondisi tidak sadar penuh atau mabuk.',

                    ],
                    [
                        'name' => 'Mengabaikan Prosedur Keselamatan',
                        'abbr' => 'BYPASS',
                        'desc' => 'Sengaja tidak mengikuti SOP atau JSA yang berlaku.',

                    ],
                    [
                        'name' => 'Bermain HP Saat Bekerja',
                        'abbr' => 'HP-USE',
                        'desc' => 'Distraksi penggunaan ponsel di area kerja aktif.',

                    ],
                ]
            ],
            [
                'name' => 'KTA (Kondisi Tidak Aman)',
                'code' => 'KTA',
                'subcategories' => [
                     [
                         'name' => 'Kondisi Lantai/Jalan Berbahaya',
                         'abbr' => 'SLIP',
                         'desc' => 'Lantai licin, berlubang, atau tidak rata.',

                     ],
                     [
                         'name' => 'Peralatan Rusak/Tidak Layak Pakai',
                         'abbr' => 'DAMAGED',
                         'desc' => 'Alat kerja yang sudah aus atau tidak berfungsi normal.',

                     ],
                     [
                         'name' => 'Pencemaran/Tumpahan B3',
                         'abbr' => 'SPILL',
                         'desc' => 'Tumpahan oli, bahan kimia, atau limbah B3 ke lingkungan.',

                     ],
                     [
                         'name' => 'Pencahayaan Tidak Memadai',
                         'abbr' => 'DARK',
                         'desc' => 'Area kerja terlalu gelap atau silau berlebihan.',

                     ],
                    [
                        'name' => 'Kabel Terkelupas',
                        'abbr' => 'CABLE',
                        'desc' => 'Bahaya tersengat listrik akibat isolasi kabel rusak.',

                    ],
                    [
                        'name' => 'Ufo Mendarat di Pit',
                        'abbr' => 'UFO',
                        'desc' => 'Ada piring terbang menghalangi jalan angkut.',

                    ],
                ]
            ],
        ];

        foreach ($categories as $catData) {
            $category = HazardCategory::updateOrCreate(
                ['code' => $catData['code']],
                ['name' => $catData['name']]
            );

            foreach ($catData['subcategories'] as $sub) {
                HazardSubcategory::updateOrCreate(
                    [
                        'category_id' => $category->id,
                        'name' => $sub['name']
                    ],
                    [
                        'abbreviation' => $sub['abbr'] ?? null,
                        'description' => $sub['desc'] ?? null,
                        'is_active' => true,
                    ]
                );
            }
        }
    }
}