<?php

namespace Database\Seeders;

use App\Models\Department;
use Illuminate\Database\Seeder;

class DepartmentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $departments = [
            'IT',
            'Operational',
            'Environmental',
            'Maintenance',
            'HSE',
            'Human Resources',
            'Finance',
            'Engineering',
            'Security',
            'Supply Chain',
        ];

        foreach ($departments as $dept) {
            Department::updateOrCreate(
                ['name' => $dept],
                ['name' => $dept]
            );
        }
    }
}