<?php

namespace Database\Seeders;

use App\Models\Announcement;
use App\Models\Inspection;
use App\Models\ChecklistItem;
use App\Models\News;
use App\Models\QrAsset;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ── Users ─────────────────────────────────────────────────────────────
        // Catatan PDF: NIK = 123 | Password = 123 (untuk demo)

        $admin = User::create([
            'nik'           => '1234567890000001',
            'employee_id'   => 'BBE-ADM-001',
            'full_name'     => 'System Administrator',
            'email'         => 'admin@bbe.com',
            'password' => Hash::make('password'),
            'phone_number'  => '+62811000001',
            'position'      => 'System Administrator',
            'department'    => 'IT',
            'role'          => 'admin',
            'is_active'     => true,
        ]);

        $supervisor = User::create([
            'nik'           => '1234567890000002',
            'employee_id'   => 'BBE-SPV-001',
            'full_name'     => 'Budi Santoso',
            'email'         => 'budi@bbe.com',
            'password' => Hash::make('password'),
            'phone_number'  => '+62811000002',
            'position'      => 'HSE Supervisor',
            'department'    => 'K3 / HSE',
            'role'          => 'supervisor',
            'is_active'     => true,
        ]);

        // Demo user sesuai PDF — NIK=123, password=123
        $demoUser = User::create([
            'nik'           => '123',
            'employee_id'   => 'BBE-DEMO-001',
            'full_name'     => 'Demo User',
            'email'         => 'demo@bbe.com',
            'password' => Hash::make('123'),
            'phone_number'  => '+62811000099',
            'position'      => 'IT Intern',
            'department'    => 'IT',
            'role'          => 'user',
            'is_active'     => true,
        ]);

        $faiz = User::create([
            'nik'           => '1234567890000003',
            'employee_id'   => 'BBE-OPS-001',
            'full_name'     => 'Muhammad Faiz',
            'email'         => 'faiz@bbe.com',
            'password' => Hash::make('password'),
            'phone_number'  => '+62811000003',
            'position'      => 'Heavy Equipment Operator',
            'department'    => 'Operational',
            'role'          => 'user',
            'is_active'     => true,
        ]);

        $lintang = User::create([
            'nik'           => '1234567890000004',
            'employee_id'   => 'BBE-OPS-002',
            'full_name'     => 'Noor Lintang Bhaskara',
            'email'         => 'lintang@bbe.com',
            'password' => Hash::make('password'),
            'phone_number'  => '+62811000004',
            'position'      => 'Workshop Technician',
            'department'    => 'Operational',
            'role'          => 'user',
            'is_active'     => true,
        ]);

        // ── Reports ───────────────────────────────────────────────────────────

        Report::create([
            'user_id'             => $faiz->id,
            'title'               => 'Dirty Safety Sign',
            'description'         => 'Safety signs in the mining area are dirty and unreadable. Immediate cleaning is required.',
            'type'                => 'hazard',
            'severity'            => 'medium',
            'status'              => 'in_progress',
            'location'            => 'Hauling Road - KM 3',
            'name_pja'            => 'Budi Santoso',
            'reported_department' => 'Operational',
        ]);

        Report::create([
            'user_id'             => $lintang->id,
            'title'               => 'Scattered Workshop Materials',
            'description'         => 'Workshop materials are scattered in front of the workshop area and blocking the evacuation route.',
            'type'                => 'hazard',
            'severity'            => 'low',
            'status'              => 'open',
            'location'            => 'Front of Workshop',
            'name_pja'            => 'Hendra Wijaya',
            'reported_department' => 'Operational',
        ]);

        Report::create([
            'user_id'             => $faiz->id,
            'title'               => 'Exposed Electrical Cable',
            'description'         => 'An electrical cable in the server room is exposed and poses a risk of electric shock.',
            'type'                => 'hazard',
            'severity'            => 'high',
            'status'              => 'open',
            'location'            => 'Server Room - 3rd Floor',
            'name_pja'            => 'Rudi Hartono',
            'reported_department' => 'IT',
        ]);

        // ── Inspections ───────────────────────────────────────────────────────

        $inspection = Inspection::create([
            'user_id'        => $supervisor->id,
            'title'          => 'Routine Heavy Equipment Inspection',
            'area'           => 'Mining Area Sector B',
            'location'       => 'Excavator Parking Bay - Sector B',
            'inspector_name' => 'Budi Santoso',
            'result'         => 'needs_follow_up',
            'notes'          => 'Excavator unit 03 shows signs of hydraulic oil leakage. Scheduled for immediate service.',
        ]);

        $checklistItems = [
            ['label' => 'Engine oil level check', 'is_checked' => true],
            ['label' => 'Hydraulic oil level check', 'is_checked' => false],
            ['label' => 'Tire/track condition check', 'is_checked' => true],
            ['label' => 'Brake system test', 'is_checked' => true],
            ['label' => 'Safety equipment availability', 'is_checked' => true],
            ['label' => 'Lights and signals check', 'is_checked' => false],
        ];

        foreach ($checklistItems as $i => $item) {
            ChecklistItem::create([
                'inspection_id' => $inspection->id,
                'label'         => $item['label'],
                'is_checked'    => $item['is_checked'],
                'sort_order'    => $i,
            ]);
        }

        // ── Announcements ─────────────────────────────────────────────────────

        Announcement::create([
            'created_by' => $admin->id,
            'title'      => 'Mandatory HSE Training — April 2026',
            'body'       => 'All employees are required to attend the HSE refresher training scheduled for April 15, 2026. The training will cover emergency response procedures, fire safety, and proper PPE usage. Attendance is mandatory. Please confirm your availability with your supervisor by April 10, 2026.',
            'is_active'  => true,
        ]);

        Announcement::create([
            'created_by' => $supervisor->id,
            'title'      => 'New PPE Policy Effective May 2026',
            'body'       => 'Effective May 1, 2026, all personnel entering the mining area must wear the updated PPE set including the new high-visibility vest and steel-toed boots compliant with ISO 20345:2022. Procurement will distribute the new equipment by April 25, 2026.',
            'is_active'  => true,
        ]);

        Announcement::create([
            'created_by' => $admin->id,
            'title'      => 'System Maintenance — April 5, 2026',
            'body'       => 'The SapaHSE system will undergo scheduled maintenance on April 5, 2026 from 22:00 to 23:00 WIB. During this window, the application may be temporarily unavailable. Please save any ongoing work before the maintenance window.',
            'is_active'  => true,
        ]);

        // ── News ──────────────────────────────────────────────────────────────

        News::create([
            'created_by'  => $supervisor->id,
            'title'       => 'APAR Socialization in Mining Area',
            'excerpt'     => 'BBE conducted a fire extinguisher socialization session for all mining area employees.',
            'content'     => 'PT. Bukit Baiduri Energi held a comprehensive APAR (Fire Extinguisher) socialization for over 150 employees across all divisions. The session covered how to identify different types of fire extinguishers, proper usage techniques, and emergency evacuation procedures. The training was led by the experienced HSE team and included live demonstrations.',
            'category'    => 'K3 / HSE',
            'author_name' => 'HSE Team BBE',
            'is_featured' => true,
            'is_active'   => true,
        ]);

        News::create([
            'created_by'  => $admin->id,
            'title'       => 'Q1 2026 Production Capacity Increase',
            'excerpt'     => 'BBE successfully increased coal production capacity by 15% in Q1 2026.',
            'content'     => 'PT. Bukit Baiduri Energi achieved a 15% increase in coal production capacity during the first quarter of 2026 compared to the same period last year. This achievement was supported by the addition of heavy equipment and optimized operational schedules. Management expressed appreciation to all employees for their dedication and hard work.',
            'category'    => 'Operational',
            'author_name' => 'Operational Division',
            'is_featured' => false,
            'is_active'   => true,
        ]);

        News::create([
            'created_by'  => $admin->id,
            'title'       => 'BBE Receives Zero Accident Award 2025',
            'excerpt'     => 'BBE was recognized by the Ministry of Manpower for achieving zero accidents throughout 2025.',
            'content'     => 'PT. Bukit Baiduri Energi proudly received the Zero Accident Award from the Ministry of Manpower of the Republic of Indonesia for maintaining a zero-accident record throughout 2025. This award is a testament to the commitment of every BBE employee in upholding a strong safety culture in the workplace.',
            'category'    => 'Achievement',
            'author_name' => 'BBE Public Relations',
            'is_featured' => true,
            'is_active'   => true,
        ]);

        // ── QR Assets ─────────────────────────────────────────────────────────

        QrAsset::create([
            'qr_code'      => 'BBE-APAR-2024-001234',
            'asset_name'   => 'Fire Extinguisher - Dry Powder 6kg',
            'asset_type'   => 'Fire Extinguisher',
            'location'     => 'Building A - 1st Floor',
            'last_checked' => now()->subMonths(3),
            'next_check'   => now()->addMonths(9),
            'condition'    => 'good',
            'notes'        => 'Last inspection passed. Pressure gauge normal.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-APAR-2024-001235',
            'asset_name'   => 'Fire Extinguisher - CO2 5kg',
            'asset_type'   => 'Fire Extinguisher',
            'location'     => 'Server Room - 3rd Floor',
            'last_checked' => now()->subMonths(2),
            'next_check'   => now()->addMonths(10),
            'condition'    => 'good',
            'notes'        => 'Suitable for electrical fires. Do not use in confined spaces.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-EXC-2023-000003',
            'asset_name'   => 'Excavator PC200 - Unit 03',
            'asset_type'   => 'Heavy Equipment',
            'location'     => 'Mining Area Sector B',
            'last_checked' => now()->subMonths(1),
            'next_check'   => now()->addMonths(2),
            'condition'    => 'needs_attention',
            'notes'        => 'Hydraulic oil leak detected. Scheduled for service on April 10, 2026.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-DMP-2023-000007',
            'asset_name'   => 'Dump Truck HD785 - Unit 07',
            'asset_type'   => 'Heavy Equipment',
            'location'     => 'Hauling Road',
            'last_checked' => now()->subDays(30),
            'next_check'   => now()->addMonths(3),
            'condition'    => 'good',
            'notes'        => 'All systems operational. Last inspection passed.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-PLT-2022-000001',
            'asset_name'   => 'Main Electrical Panel',
            'asset_type'   => 'Electrical',
            'location'     => 'Workshop Electrical Room',
            'last_checked' => now()->subMonths(5),
            'next_check'   => now()->subMonths(1), // overdue!
            'condition'    => 'unfit',
            'notes'        => 'Inspection overdue. Do not operate until cleared by electrical team.',
        ]);
    }
}