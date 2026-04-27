<?php

namespace Database\Seeders;

use App\Models\Area;
use App\Models\Company;
use Illuminate\Database\Seeder;

class AreaSeeder extends Seeder
{
    public function run(): void
    {
        $bbe = Company::where('code', 'BBE')->first();
        $kma = Company::where('code', 'KMA')->first();

        // Area khusus BBE
        if ($bbe) {
            $bbeAreas = [
                ['name' => 'Mining Area Sektor A', 'code' => 'MIN-A'],
                ['name' => 'Mining Area Sektor B', 'code' => 'MIN-B'],
                ['name' => 'Hauling Road KM 1-5', 'code' => 'HR-1'],
                ['name' => 'Workshop Utama BBE', 'code' => 'WS-BBE'],
                ['name' => 'Jetty Port BBE', 'code' => 'JETTY-BBE'],
            ];

            foreach ($bbeAreas as $area) {
                Area::updateOrCreate(
                    ['company_id' => $bbe->id, 'name' => $area['name']],
                    ['code' => $area['code'], 'is_active' => true]
                );
            }
        }

        // Area khusus KMA
        if ($kma) {
            $kmaAreas = [
                ['name' => 'Mining Area Sektor C', 'code' => 'MIN-C'],
                ['name' => 'Mining Area Sektor D', 'code' => 'MIN-D'],
                ['name' => 'Hauling Road KM 6-10', 'code' => 'HR-2'],
                ['name' => 'Workshop Utama KMA', 'code' => 'WS-KMA'],
                ['name' => 'Jetty Port KMA', 'code' => 'JETTY-KMA'],
            ];

            foreach ($kmaAreas as $area) {
                Area::updateOrCreate(
                    ['company_id' => $kma->id, 'name' => $area['name']],
                    ['code' => $area['code'], 'is_active' => true]
                );
            }
        }
    }
}