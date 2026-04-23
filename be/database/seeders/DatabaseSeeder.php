<?php

namespace Database\Seeders;

use App\Models\Announcement;
use App\Models\ChecklistItem;
use App\Models\News;
use App\Models\Notification;
use App\Models\QrAsset;
use App\Models\HazardReport;
use App\Models\InspectionReport;
use App\Models\ReportLog;
use App\Models\User;
use App\Models\UserCertification;
use App\Models\UserLicense;
use App\Models\UserMedical;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ══════════════════════════════════════════════════════════════════
        // USERS
        // Kolom login: staff_id + password_hash
        // Role: superadmin | admin | user
        //
        // Demo login: staff_id = "1" | password = "123"
        // ══════════════════════════════════════════════════════════════════

        $superadmin = User::create([
            'employee_id'       => 'BBE-SA-01',
            'full_name'      => 'Ahmad Fauzan',
            'personal_email' => 'superadmin@bbe.com',
            'work_email'     => 'a.fauzan@bbe.co.id',
            'phone_number'   => '+62811000001',
            'position'       => 'System Administrator',
            'department'     => 'IT',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'superadmin',
            'tipe_afiliasi'  => 'owner',
            'email_verified_at' => now(),
        ]);

        $admin = User::create([
            'employee_id'       => 'BBE-AD-01',
            'full_name'      => 'Budi Santoso',
            'personal_email' => 'budi@bbe.com',
            'work_email'     => 'b.santoso@bbe.co.id',
            'phone_number'   => '+62811000002',
            'position'       => 'HSE Manager',
            'department'     => 'K3 / HSE',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'admin',
            'tipe_afiliasi'  => 'owner',
            'email_verified_at' => now(),
        ]);

        $admin2 = User::create([
            'employee_id'       => 'BBE-AD-02',
            'full_name'      => 'Sari Dewi Rahayu',
            'personal_email' => 'sari@bbe.com',
            'work_email'     => 's.dewi@bbe.co.id',
            'phone_number'   => '+62811000003',
            'position'       => 'Mine Safety Inspector',
            'department'     => 'K3 / HSE',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'admin',
            'email_verified_at' => now(),
        ]);

        // Demo user — staff_id = "1", password = "123"
        $demo = User::create([
            'employee_id'       => '1',
            'full_name'      => 'Demo User',
            'personal_email' => 'demo@bbe.com',
            'work_email'     => null,
            'phone_number'   => '+62811000099',
            'position'       => 'IT Intern',
            'department'     => 'IT',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('123'),
            'is_active'      => true,
            'role'           => 'user',
            'email_verified_at' => now(),
        ]);

        $faiz = User::create([
            'employee_id'       => 'BBE-OP-01',
            'full_name'      => 'Muhammad Faiz',
            'personal_email' => 'faiz@bbe.com',
            'work_email'     => 'm.faiz@bbe.co.id',
            'phone_number'   => '+62811000004',
            'position'       => 'Heavy Equipment Operator',
            'department'     => 'Operational',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'user',
            'tipe_afiliasi'  => 'kontraktor',
            'perusahaan_kontraktor' => 'PT PAMA',
            'email_verified_at' => now(),
        ]);

        $lintang = User::create([
            'employee_id'       => 'BBE-OP-02',
            'full_name'      => 'Noor Lintang Bhaskara',
            'personal_email' => 'lintang@bbe.com',
            'work_email'     => 'n.lintang@bbe.co.id',
            'phone_number'   => '+62811000005',
            'position'       => 'Workshop Technician',
            'department'     => 'Operational',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'user',
            'email_verified_at' => now(),
        ]);

        $rudi = User::create([
            'employee_id'       => 'BBE-MN-01',
            'full_name'      => 'Rudi Hartono',
            'personal_email' => 'rudi@bbe.com',
            'work_email'     => 'r.hartono@bbe.co.id',
            'phone_number'   => '+62811000006',
            'position'       => 'Electrical Maintenance',
            'department'     => 'Maintenance',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'user',
            'email_verified_at' => now(),
        ]);

        $putri = User::create([
            'employee_id'       => 'BBE-EV-01',
            'full_name'      => 'Putri Handayani',
            'personal_email' => 'putri@bbe.com',
            'work_email'     => 'p.handayani@bbe.co.id',
            'phone_number'   => '+62811000007',
            'position'       => 'Environmental Officer',
            'department'     => 'Environmental',
            'company'        => 'PT Bukit Baiduri Energi',
            'password_hash'  => Hash::make('password'),
            'is_active'      => true,
            'role'           => 'user',
            'email_verified_at' => now(),
        ]);

        // ══════════════════════════════════════════════════════════════════
        // USER LICENSES
        // ══════════════════════════════════════════════════════════════════

        UserLicense::create([
            'user_id'        => $faiz->id,
            'name'           => 'SIM B2 Umum (Alat Berat)',
            'license_number' => 'SIM-B2-2021-001234',
            'expired_at'     => now()->addYears(2)->toDateString(),
            'status'         => 'active',
        ]);
        UserLicense::create([
            'user_id'        => $faiz->id,
            'name'           => 'Lisensi Operator Excavator K3',
            'license_number' => 'LOP-EXC-2022-00456',
            'expired_at'     => now()->addYear()->toDateString(),
            'status'         => 'active',
        ]);
        UserLicense::create([
            'user_id'        => $lintang->id,
            'name'           => 'Sertifikat Ahli K3 Umum',
            'license_number' => 'AK3U-2020-007811',
            'expired_at'     => now()->subMonths(4)->toDateString(),
            'status'         => 'expired',
        ]);
        UserLicense::create([
            'user_id'        => $lintang->id,
            'name'           => 'Lisensi Las SMAW (BNSP)',
            'license_number' => 'LAS-SMAW-2023-00099',
            'expired_at'     => now()->addYears(3)->toDateString(),
            'status'         => 'active',
        ]);
        UserLicense::create([
            'user_id'        => $rudi->id,
            'name'           => 'Sertifikat Instalatir Listrik Madya',
            'license_number' => 'INST-MAD-2021-00532',
            'expired_at'     => now()->addYear()->toDateString(),
            'status'         => 'active',
        ]);
        UserLicense::create([
            'user_id'        => $admin->id,
            'name'           => 'Ahli K3 Madya Pertambangan',
            'license_number' => 'AK3-MADYA-2020-00188',
            'expired_at'     => now()->addMonths(8)->toDateString(),
            'status'         => 'active',
        ]);
        UserLicense::create([
            'user_id'        => $putri->id,
            'name'           => 'AMDAL Dasar (Kementerian LHK)',
            'license_number' => 'AMDAL-D-2022-00341',
            'expired_at'     => now()->addYears(4)->toDateString(),
            'status'         => 'active',
        ]);

        // ══════════════════════════════════════════════════════════════════
        // USER CERTIFICATIONS
        // ══════════════════════════════════════════════════════════════════

        UserCertification::create([
            'user_id' => $faiz->id,
            'name'    => 'Pelatihan Operator Alat Berat Tingkat Dasar',
            'issuer'  => 'Kemnaker RI',
            'year'    => 2021,
            'status'  => 'active',
        ]);
        UserCertification::create([
            'user_id' => $faiz->id,
            'name'    => 'Basic Safety Training (BST)',
            'issuer'  => 'BNSP',
            'year'    => 2022,
            'status'  => 'active',
        ]);
        UserCertification::create([
            'user_id' => $lintang->id,
            'name'    => 'Welding Inspector Level 1',
            'issuer'  => 'BNSP',
            'year'    => 2023,
            'status'  => 'active',
        ]);
        UserCertification::create([
            'user_id' => $rudi->id,
            'name'    => 'Hazardous Area Installation (HAI)',
            'issuer'  => 'PLN Pusdiklat',
            'year'    => 2021,
            'status'  => 'active',
        ]);
        UserCertification::create([
            'user_id' => $rudi->id,
            'name'    => 'Pelatihan Keselamatan Listrik',
            'issuer'  => 'Kemnaker RI',
            'year'    => 2019,
            'status'  => 'expired',
        ]);
        UserCertification::create([
            'user_id' => $admin->id,
            'name'    => 'OHSE Management System (ISO 45001)',
            'issuer'  => 'SGS Indonesia',
            'year'    => 2022,
            'status'  => 'active',
        ]);
        UserCertification::create([
            'user_id' => $admin2->id,
            'name'    => 'Incident Investigation & Root Cause Analysis',
            'issuer'  => 'IOSH',
            'year'    => 2023,
            'status'  => 'active',
        ]);
        UserCertification::create([
            'user_id' => $putri->id,
            'name'    => 'Environmental Compliance Auditor',
            'issuer'  => 'KLHK',
            'year'    => 2022,
            'status'  => 'active',
        ]);

        // ══════════════════════════════════════════════════════════════════
        // USER MEDICALS
        // ══════════════════════════════════════════════════════════════════

        UserMedical::create([
            'user_id'           => $faiz->id,
            'checkup_date'      => now()->subMonths(6)->toDateString(),
            'blood_type'        => 'O+',
            'height'            => '172 cm',
            'weight'            => '70 kg',
            'blood_pressure'    => '118/76 mmHg',
            'allergies'         => 'Tidak ada',
            'result'            => 'Fit to Work',
            'next_checkup_date' => now()->addMonths(6)->toDateString(),
        ]);
        UserMedical::create([
            'user_id'           => $faiz->id,
            'checkup_date'      => now()->subYear()->toDateString(),
            'blood_type'        => 'O+',
            'height'            => '172 cm',
            'weight'            => '68 kg',
            'blood_pressure'    => '120/78 mmHg',
            'allergies'         => 'Tidak ada',
            'result'            => 'Fit to Work',
            'next_checkup_date' => now()->subMonths(6)->toDateString(),
        ]);
        UserMedical::create([
            'user_id'           => $lintang->id,
            'checkup_date'      => now()->subMonths(3)->toDateString(),
            'blood_type'        => 'A+',
            'height'            => '168 cm',
            'weight'            => '65 kg',
            'blood_pressure'    => '122/80 mmHg',
            'allergies'         => 'Debu logam',
            'result'            => 'Fit with Restriction',
            'next_checkup_date' => now()->addMonths(9)->toDateString(),
        ]);
        UserMedical::create([
            'user_id'           => $rudi->id,
            'checkup_date'      => now()->subMonths(5)->toDateString(),
            'blood_type'        => 'B+',
            'height'            => '175 cm',
            'weight'            => '78 kg',
            'blood_pressure'    => '130/85 mmHg',
            'allergies'         => 'Tidak ada',
            'result'            => 'Fit to Work',
            'next_checkup_date' => now()->addMonths(7)->toDateString(),
        ]);
        UserMedical::create([
            'user_id'           => $admin->id,
            'checkup_date'      => now()->subMonths(4)->toDateString(),
            'blood_type'        => 'AB+',
            'height'            => '170 cm',
            'weight'            => '72 kg',
            'blood_pressure'    => '115/75 mmHg',
            'allergies'         => 'Tidak ada',
            'result'            => 'Fit to Work',
            'next_checkup_date' => now()->addMonths(8)->toDateString(),
        ]);
        UserMedical::create([
            'user_id'           => $putri->id,
            'checkup_date'      => now()->subMonths(2)->toDateString(),
            'blood_type'        => 'A-',
            'height'            => '160 cm',
            'weight'            => '55 kg',
            'blood_pressure'    => '110/70 mmHg',
            'allergies'         => 'Polutan kimia',
            'result'            => 'Fit to Work',
            'next_checkup_date' => now()->addMonths(10)->toDateString(),
        ]);

        // ══════════════════════════════════════════════════════════════════
        // REPORTS  (type: hazard | inspection)
        // ══════════════════════════════════════════════════════════════════

        $r1 = HazardReport::create([
            'ticket_number'       => 'BBE-HZR-HSE-2026-000001',
            'user_id'             => $faiz->id,
            'title'               => 'Rambu Keselamatan Kotor & Tidak Terbaca',
            'description'         => 'Rambu keselamatan di area hauling road KM 3 sudah kotor dan warna pudar sehingga sulit dibaca oleh pengemudi dump truck, berpotensi menyebabkan kecelakaan lalu lintas tambang.',
            'severity'            => 'high',
            'status'              => 'in_progress',
            'sub_status'          => 'executing',
            'location'            => 'Hauling Road KM 3',
            'pic_department'      => 'Budi Santoso, Sari Dewi Rahayu',
            'reported_department' => 'Operational',
            'hazard_category'     => 'KTA',
            'hazard_subcategory'  => 'Perlengkapan Keselamatan Rusak/Hilang',
            'suggestion'          => 'Segera bersihkan atau ganti rambu baru jika sudah buram agar mudah terlihat di malam hari.',
            'pelaku_pelanggaran'  => 'Unknown Driver',
            'pelapor_location'    => '-0.4948, 117.1436',
            'kejadian_location'   => '-0.4949, 117.1437',
        ]);

        $r2 = HazardReport::create([
            'ticket_number'       => 'BBE-HZR-HSE-2026-000002',
            'user_id'             => $lintang->id,
            'title'               => 'Material Workshop Berserakan di Jalur Evakuasi',
            'description'         => 'Material workshop berupa pipa besi dan suku cadang berserakan di depan pintu keluar workshop, menghalangi jalur evakuasi darurat yang seharusnya selalu bersih.',
            'severity'            => 'low',
            'status'              => 'open',
            'sub_status'          => 'validating',
            'location'            => 'Depan Workshop Utama',
            'pic_department'      => 'Hendra Wijaya',
            'reported_department' => 'Operational',
            'hazard_category'     => 'TTA',
            'hazard_subcategory'  => 'Housekeeping Buruk',
            'suggestion'          => 'Pindahkan material ke area penyimpanan khusus. Jangan tinggalkan barang di jalur evakuasi.',
            'pelaku_pelanggaran'  => 'Mechanical Team A',
        ]);

        $r3 = HazardReport::create([
            'ticket_number'       => 'BBE-HZR-HSE-2026-000003',
            'user_id'             => $rudi->id,
            'title'               => 'Kabel Listrik Terbuka di Ruang Server',
            'description'         => 'Kabel listrik bertegangan 220V di sudut ruang server lantai 3 terkelupas isolasinya, berpotensi menyebabkan sengatan listrik atau kebakaran pada perangkat server.',
            'severity'            => 'medium',
            'status'              => 'open',
            'sub_status'          => 'approved',
            'location'            => 'Ruang Server - Lantai 3',
            'pic_department'      => 'Rudi Hartono, IT Department',
            'reported_department' => 'IT',
            'hazard_category'     => 'KTA',
            'hazard_subcategory'  => 'Instalasi Listrik Tidak Aman',
            'suggestion'          => 'Isolasi segera atau ganti kabel dan masukkan ke dalam pipa conduit.',
        ]);

        $r4 = HazardReport::create([
            'ticket_number'       => 'BBE-HZR-HSE-2026-000004',
            'user_id'             => $demo->id,
            'title'               => 'Tumpahan Oli Hydraulic di Area Parkir Alat Berat',
            'description'         => 'Terdapat tumpahan oli hydraulic dari excavator PC200 Unit 03 di area parkir Sektor B. Genangan oli licin dapat menyebabkan karyawan terpeleset.',
            'severity'            => 'high',
            'status'              => 'closed',
            'sub_status'          => 'resolved',
            'location'            => 'Parkir Alat Berat - Sektor B',
            'pic_department'      => 'Budi Santoso',
            'reported_department' => 'Operational',
            'hazard_category'     => 'KTA',
            'hazard_subcategory'  => 'Pencemaran/Tumpahan B3',
            'suggestion'          => 'Gunakan oil absorber dan panggil petugas maintenance untuk membersihkan lantai parkiran.',
            'kejadian_location'   => '-0.4920, 117.1410',
        ]);

        $r5 = HazardReport::create([
            'ticket_number'       => 'BBE-HZR-HSE-2026-000005',
            'user_id'             => $putri->id,
            'title'               => 'Pembuangan Limbah B3 Tidak Sesuai SOP',
            'description'         => 'Ditemukan wadah limbah B3 berupa bekas cat dan thinner yang dibuang sembarangan di area belakang gudang, tidak sesuai prosedur pengelolaan limbah B3 KLHK.',
            'severity'            => 'medium',
            'status'              => 'in_progress',
            'sub_status'          => 'preparing',
            'location'            => 'Belakang Gudang Material',
            'pic_department'      => 'Sari Dewi Rahayu, Environmental Dept',
            'reported_department' => 'Environmental',
            'hazard_category'     => 'TTA',
            'hazard_subcategory'  => 'Pelanggaran Prosedur K3/Lingkungan',
            'suggestion'          => 'Tegur pekerja yang bertanggung jawab dan edukasi ulang tentang SOP limbah B3.',
            'pelaku_pelanggaran'  => 'Sub-con Painter Team',
        ]);

        $r6 = InspectionReport::create([
            'ticket_number'  => 'BBE-ISP-HSE-2026-000001',
            'user_id'        => $admin->id,
            'title'          => 'Inspeksi Rutin Alat Berat - Excavator Sektor B',
            'description'    => 'Inspeksi berkala bulanan excavator di area pertambangan Sektor B untuk memastikan kondisi operasional dan keselamatan.',
            'status'         => 'closed',
            'sub_status'     => 'resolved',
            'location'       => 'Area Parkir Excavator - Sektor B',
            'area'           => 'Mining Area Sektor B',
            'name_inspector' => 'Budi Santoso',
            'result'         => 'needs_follow_up',
            'notes'          => 'Excavator Unit 03 menunjukkan tanda kebocoran oli hydraulic. Dijadwalkan service segera.',
        ]);

        $r7 = InspectionReport::create([
            'ticket_number'  => 'BBE-ISP-HSE-2026-000002',
            'user_id'        => $admin2->id,
            'title'          => 'Inspeksi APAR Seluruh Gedung Kantor',
            'description'    => 'Pemeriksaan kondisi dan kelengkapan APAR di seluruh gedung kantor pusat BBE untuk memastikan kesiapan menghadapi darurat kebakaran.',
            'status'         => 'open',
            'sub_status'     => 'assigned',
            'location'       => 'Gedung Kantor Pusat BBE',
            'area'           => 'Gedung Kantor',
            'name_inspector' => 'Sari Dewi Rahayu',
            'result'         => 'compliant',
            'notes'          => 'Semua APAR dalam kondisi baik. Segel utuh, tekanan normal.',
        ]);

        $r8 = InspectionReport::create([
            'ticket_number'  => 'BBE-ISP-HSE-2026-000003',
            'user_id'        => $admin->id,
            'title'          => 'Inspeksi Pemakaian APD Karyawan Area Tambang',
            'description'    => 'Inspeksi pemakaian Alat Pelindung Diri karyawan di area pertambangan aktif untuk memastikan kepatuhan terhadap standar K3.',
            'status'         => 'in_progress',
            'sub_status'     => 'reviewing',
            'location'       => 'Area Tambang Aktif Sektor A',
            'area'           => 'Mining Area Sektor A',
            'name_inspector' => 'Budi Santoso',
            'result'         => 'non_compliant',
            'notes'          => '3 dari 12 karyawan tidak menggunakan safety glasses. Diberikan teguran dan APD pengganti.',
        ]);

        // Checklist items
        foreach ([
            ['label' => 'Cek level oli mesin',         'is_checked' => true,  'sort_order' => 0],
            ['label' => 'Cek level oli hydraulic',      'is_checked' => false, 'sort_order' => 1],
            ['label' => 'Cek kondisi track/roda',       'is_checked' => true,  'sort_order' => 2],
            ['label' => 'Uji sistem rem',               'is_checked' => true,  'sort_order' => 3],
            ['label' => 'Ketersediaan APAR di kabin',   'is_checked' => true,  'sort_order' => 4],
            ['label' => 'Cek lampu dan sinyal',         'is_checked' => false, 'sort_order' => 5],
        ] as $item) {
            ChecklistItem::create(array_merge($item, ['inspection_report_id' => $r6->id]));
        }

        foreach ([
            ['label' => 'Segel APAR masih utuh',         'is_checked' => true,  'sort_order' => 0],
            ['label' => 'Tekanan manometer dalam range',  'is_checked' => true,  'sort_order' => 1],
            ['label' => 'Label identifikasi terbaca',     'is_checked' => true,  'sort_order' => 2],
            ['label' => 'Pin pengaman terpasang',         'is_checked' => true,  'sort_order' => 3],
            ['label' => 'Tabung tidak berkarat/bocor',    'is_checked' => true,  'sort_order' => 4],
            ['label' => 'Lokasi APAR sesuai denah',       'is_checked' => true,  'sort_order' => 5],
        ] as $item) {
            ChecklistItem::create(array_merge($item, ['inspection_report_id' => $r7->id]));
        }

        foreach ([
            ['label' => 'Helm keselamatan dipakai',  'is_checked' => true,  'sort_order' => 0],
            ['label' => 'Safety vest terpasang',      'is_checked' => true,  'sort_order' => 1],
            ['label' => 'Safety glasses dipakai',     'is_checked' => false, 'sort_order' => 2],
            ['label' => 'Safety shoes dipakai',       'is_checked' => true,  'sort_order' => 3],
            ['label' => 'Safety gloves tersedia',     'is_checked' => true,  'sort_order' => 4],
        ] as $item) {
            ChecklistItem::create(array_merge($item, ['inspection_report_id' => $r8->id]));
        }

        // ══════════════════════════════════════════════════════════════════
        // REPORT LOGS
        // ══════════════════════════════════════════════════════════════════

        ReportLog::create(['reportable_id' => $r1->id, 'reportable_type' => HazardReport::class, 'user_id' => $faiz->id,   'status' => 'open',        'sub_status' => 'validating', 'message' => 'Laporan hazard baru dibuat.',                                                    'created_at' => now()->subDays(5)]);
        ReportLog::create(['reportable_id' => $r1->id, 'reportable_type' => HazardReport::class, 'user_id' => $admin->id,  'status' => 'in_progress', 'sub_status' => 'executing',  'message' => 'Laporan divalidasi dan tim cleaning dijadwalkan.',                             'created_at' => now()->subDays(4)]);

        ReportLog::create(['reportable_id' => $r2->id, 'reportable_type' => HazardReport::class, 'user_id' => $lintang->id,'status' => 'open',        'sub_status' => 'validating', 'message' => 'Laporan hazard baru dibuat.',                                                    'created_at' => now()->subDays(3)]);
        // Menambahkan tagged user (Rudi) di log r2
        ReportLog::create(['reportable_id' => $r2->id, 'reportable_type' => HazardReport::class, 'user_id' => $admin->id,'status' => 'open',        'sub_status' => 'validating', 'message' => 'Harap bantu pengecekan lapangan terkait isu ini.', 'tagged_user_id' => $rudi->id,   'created_at' => now()->subDays(2)]);

        ReportLog::create(['reportable_id' => $r3->id, 'reportable_type' => HazardReport::class, 'user_id' => $rudi->id,   'status' => 'open',        'sub_status' => 'approved',   'message' => 'Laporan hazard baru dibuat.',                                                    'created_at' => now()->subDays(2)]);

        ReportLog::create(['reportable_id' => $r4->id, 'reportable_type' => HazardReport::class, 'user_id' => $demo->id,   'status' => 'open',        'sub_status' => 'validating', 'message' => 'Laporan hazard baru dibuat.',                                                    'created_at' => now()->subDays(10)]);
        ReportLog::create(['reportable_id' => $r4->id, 'reportable_type' => HazardReport::class, 'user_id' => $admin->id,  'status' => 'in_progress', 'sub_status' => 'executing',  'message' => 'Tim maintenance ditugaskan untuk pembersihan area.',                            'created_at' => now()->subDays(8)]);
        ReportLog::create(['reportable_id' => $r4->id, 'reportable_type' => HazardReport::class, 'user_id' => $admin->id,  'status' => 'closed',      'sub_status' => 'resolved',   'message' => 'Area telah dibersihkan dan oil absorber dipasang. Laporan ditutup.',            'created_at' => now()->subDays(7)]);

        ReportLog::create(['reportable_id' => $r5->id, 'reportable_type' => HazardReport::class, 'user_id' => $putri->id,  'status' => 'open',        'sub_status' => 'validating', 'message' => 'Laporan hazard baru dibuat.',                                                    'created_at' => now()->subDays(6)]);
        ReportLog::create(['reportable_id' => $r5->id, 'reportable_type' => HazardReport::class, 'user_id' => $admin2->id, 'status' => 'in_progress', 'sub_status' => 'preparing',  'message' => 'Limbah dipindahkan sementara, koordinasi dengan tim environmental dimulai.',    'created_at' => now()->subDays(5)]);

        ReportLog::create(['reportable_id' => $r6->id, 'reportable_type' => InspectionReport::class, 'user_id' => $admin->id,  'status' => 'open',        'sub_status' => 'validating', 'message' => 'Laporan inspeksi baru dibuat.',                                                  'created_at' => now()->subDays(14)]);
        ReportLog::create(['reportable_id' => $r6->id, 'reportable_type' => InspectionReport::class, 'user_id' => $admin->id,  'status' => 'in_progress', 'sub_status' => 'executing',  'message' => 'Inspeksi sedang berjalan di lapangan.',                                         'created_at' => now()->subDays(14)]);
        ReportLog::create(['reportable_id' => $r6->id, 'reportable_type' => InspectionReport::class, 'user_id' => $admin->id,  'status' => 'closed',      'sub_status' => 'resolved',   'message' => 'Inspeksi selesai. Excavator Unit 03 dijadwalkan service.',                      'created_at' => now()->subDays(13)]);

        ReportLog::create(['reportable_id' => $r7->id, 'reportable_type' => InspectionReport::class, 'user_id' => $admin2->id, 'status' => 'open',        'sub_status' => 'assigned',   'message' => 'Laporan inspeksi baru dibuat.',                                                  'created_at' => now()->subDay()]);
        ReportLog::create(['reportable_id' => $r8->id, 'reportable_type' => InspectionReport::class, 'user_id' => $admin->id,  'status' => 'open',        'sub_status' => 'validating', 'message' => 'Laporan inspeksi baru dibuat.',                                                  'created_at' => now()->subDays(2)]);
        ReportLog::create(['reportable_id' => $r8->id, 'reportable_type' => InspectionReport::class, 'user_id' => $admin->id,  'status' => 'in_progress', 'sub_status' => 'reviewing',  'message' => 'Teguran diberikan, pemantauan lanjutan dijadwalkan.',                           'created_at' => now()->subDay()]);

        // ══════════════════════════════════════════════════════════════════
        // ANNOUNCEMENTS  (dibuat oleh admin/superadmin)
        // ══════════════════════════════════════════════════════════════════

        Announcement::create([
            'created_by' => $superadmin->id,
            'title'      => 'Pelatihan K3 Wajib — April 2026',
            'body'       => 'Seluruh karyawan diwajibkan mengikuti pelatihan K3 yang dijadwalkan pada 15 April 2026. Pelatihan mencakup prosedur tanggap darurat, keselamatan kebakaran, dan penggunaan APD yang benar. Kehadiran bersifat wajib. Konfirmasi kehadiran kepada supervisor masing-masing paling lambat 10 April 2026.',
            'is_active'  => true,
        ]);

        Announcement::create([
            'created_by' => $admin->id,
            'title'      => 'Kebijakan APD Baru Berlaku Mei 2026',
            'body'       => 'Mulai 1 Mei 2026, seluruh personel yang memasuki area pertambangan wajib menggunakan set APD terbaru termasuk rompi high-visibility dan sepatu keselamatan sesuai ISO 20345:2022. Pengadaan akan mendistribusikan perlengkapan baru sebelum 25 April 2026.',
            'is_active'  => true,
        ]);

        Announcement::create([
            'created_by' => $superadmin->id,
            'title'      => 'Pemeliharaan Sistem SapaHSE — 5 April 2026',
            'body'       => 'Sistem SapaHSE akan menjalani pemeliharaan terjadwal pada 5 April 2026 pukul 22.00–23.00 WIB. Selama jendela ini, aplikasi mungkin tidak dapat diakses sementara. Harap simpan pekerjaan yang sedang berlangsung sebelum pemeliharaan dimulai.',
            'is_active'  => true,
        ]);

        Announcement::create([
            'created_by' => $admin2->id,
            'title'      => 'Simulasi Evakuasi Darurat — 20 April 2026',
            'body'       => 'Departemen HSE akan mengadakan simulasi evakuasi darurat menyeluruh pada 20 April 2026 pukul 09.00 WIB. Seluruh karyawan diwajibkan hadir. Simulasi bertujuan menguji kesiapan prosedur evakuasi dan memperbarui pemahaman tentang titik kumpul.',
            'is_active'  => true,
        ]);

        Announcement::create([
            'created_by' => $superadmin->id,
            'title'      => 'Kebijakan Zero Tolerance Terhadap Pelanggaran K3',
            'body'       => 'Manajemen PT Bukit Baiduri Energi menegaskan kembali kebijakan zero tolerance terhadap pelanggaran keselamatan kerja. Setiap pelanggaran akan ditindak sesuai prosedur disiplin perusahaan. Seluruh karyawan diminta untuk segera melaporkan potensi bahaya melalui aplikasi SapaHSE.',
            'is_active'  => true,
        ]);

        // ══════════════════════════════════════════════════════════════════
        // NEWS & ARTICLES
        // ══════════════════════════════════════════════════════════════════

        News::create([
            'created_by'  => $admin->id,
            'title'       => 'Sosialisasi APAR di Area Pertambangan',
            'excerpt'     => 'BBE mengadakan sesi sosialisasi alat pemadam api ringan bagi seluruh karyawan area tambang.',
            'content'     => 'PT. Bukit Baiduri Energi mengadakan sosialisasi APAR komprehensif untuk lebih dari 150 karyawan di seluruh divisi. Sesi ini mencakup cara mengidentifikasi jenis APAR, teknik penggunaan yang tepat, dan prosedur evakuasi darurat. Pelatihan dipimpin oleh tim HSE berpengalaman dan disertai demonstrasi langsung menggunakan api sungguhan di ruang terbuka.',
            'category'    => 'K3 / HSE',
            'author_name' => 'Tim HSE BBE',
            'is_featured' => true,
            'is_active'   => true,
            'image_url'   => 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
        ]);

        News::create([
            'created_by'  => $superadmin->id,
            'title'       => 'Peningkatan Kapasitas Produksi Q1 2026 Capai 15%',
            'excerpt'     => 'BBE berhasil meningkatkan kapasitas produksi batubara sebesar 15% pada Q1 2026.',
            'content'     => 'PT. Bukit Baiduri Energi mencatat peningkatan kapasitas produksi batubara sebesar 15% pada kuartal pertama tahun 2026 dibandingkan periode yang sama tahun lalu. Pencapaian ini didukung oleh penambahan alat berat dan optimalisasi jadwal operasional.',
            'category'    => 'Operasional',
            'author_name' => 'Divisi Operational BBE',
            'is_featured' => false,
            'is_active'   => true,
            'image_url'   => 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800&q=80',
        ]);

        News::create([
            'created_by'  => $superadmin->id,
            'title'       => 'BBE Terima Penghargaan Zero Accident 2025',
            'excerpt'     => 'BBE mendapat penghargaan dari Kemnaker RI atas pencapaian zero accident sepanjang 2025.',
            'content'     => 'PT. Bukit Baiduri Energi dengan bangga menerima Penghargaan Zero Accident dari Kementerian Ketenagakerjaan Republik Indonesia atas catatan nol kecelakaan sepanjang tahun 2025. Penghargaan ini merupakan bukti komitmen seluruh karyawan BBE dalam menjunjung budaya keselamatan kerja.',
            'category'    => 'Prestasi',
            'author_name' => 'Humas BBE',
            'is_featured' => true,
            'is_active'   => true,
            'image_url'   => 'https://images.unsplash.com/photo-1567427017947-545c5f8d16ad?w=800&q=80',
        ]);

        News::create([
            'created_by'  => $admin2->id,
            'title'       => 'Update SOP Pengelolaan Limbah B3 Sesuai Regulasi KLHK',
            'excerpt'     => 'KLHK menerbitkan regulasi baru terkait limbah B3 dan BBE segera merespons.',
            'content'     => 'Kementerian Lingkungan Hidup dan Kehutanan (KLHK) menerbitkan regulasi terbaru terkait pengelolaan limbah bahan berbahaya dan beracun (B3). BBE langsung memperbarui seluruh SOP yang berkaitan dan menjadwalkan pelatihan untuk tim environmental.',
            'category'    => 'Regulasi',
            'author_name' => 'Tim Environmental BBE',
            'is_featured' => false,
            'is_active'   => true,
            'image_url'   => 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&q=80',
        ]);

        News::create([
            'created_by'  => $admin->id,
            'title'       => 'Jadwal Inspeksi Rutin Area Tambang April 2026',
            'excerpt'     => 'Tim K3 BBE akan melaksanakan inspeksi rutin di seluruh area tambang sepanjang April 2026.',
            'content'     => 'Tim K3 PT. Bukit Baiduri Energi akan melaksanakan program inspeksi rutin menyeluruh di seluruh area tambang sepanjang bulan April 2026. Inspeksi mencakup kondisi alat berat, instalasi listrik, fasilitas K3, dan kepatuhan prosedur kerja para operator.',
            'category'    => 'Operasional',
            'author_name' => 'Tim K3 BBE',
            'is_featured' => false,
            'is_active'   => true,
            'image_url'   => 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&q=80',
        ]);

        News::create([
            'created_by'  => $superadmin->id,
            'title'       => 'BBE Terima PROPER Emas dari KLHK 2026',
            'excerpt'     => 'Penghargaan lingkungan tertinggi diraih BBE untuk ketiga kalinya secara berturut-turut.',
            'content'     => 'PT. Bukit Baiduri Energi kembali mendapatkan penghargaan tertinggi Program Penilaian Peringkat Kinerja Perusahaan (PROPER) Emas dari KLHK. Penghargaan ini merupakan yang ketiga kalinya diraih BBE secara berturut-turut.',
            'category'    => 'Prestasi',
            'author_name' => 'Humas BBE',
            'is_featured' => true,
            'is_active'   => true,
            'image_url'   => 'https://images.unsplash.com/photo-1611273426858-450d8e3c9fce?w=800&q=80',
        ]);

        // ══════════════════════════════════════════════════════════════════
        // QR ASSETS
        // ══════════════════════════════════════════════════════════════════

        QrAsset::create([
            'qr_code'      => 'BBE-APAR-2024-001234',
            'asset_name'   => 'APAR Dry Powder 6kg',
            'asset_type'   => 'Fire Extinguisher',
            'location'     => 'Gedung A - Lantai 1',
            'last_checked' => now()->subMonths(3),
            'next_check'   => now()->addMonths(9),
            'condition'    => 'good',
            'notes'        => 'Inspeksi terakhir lulus. Manometer menunjukkan tekanan normal.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-APAR-2024-001235',
            'asset_name'   => 'APAR CO2 5kg',
            'asset_type'   => 'Fire Extinguisher',
            'location'     => 'Ruang Server - Lantai 3',
            'last_checked' => now()->subMonths(2),
            'next_check'   => now()->addMonths(10),
            'condition'    => 'good',
            'notes'        => 'Cocok untuk kebakaran listrik. Jangan gunakan di ruang tertutup.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-EXC-2023-000003',
            'asset_name'   => 'Excavator PC200 - Unit 03',
            'asset_type'   => 'Heavy Equipment',
            'location'     => 'Area Parkir Alat Berat - Sektor B',
            'last_checked' => now()->subMonths(1),
            'next_check'   => now()->addMonths(2),
            'condition'    => 'needs_attention',
            'notes'        => 'Kebocoran oli hydraulic terdeteksi. Dijadwalkan service 10 April 2026.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-DMP-2023-000007',
            'asset_name'   => 'Dump Truck HD785 - Unit 07',
            'asset_type'   => 'Heavy Equipment',
            'location'     => 'Hauling Road',
            'last_checked' => now()->subDays(30),
            'next_check'   => now()->addMonths(3),
            'condition'    => 'good',
            'notes'        => 'Semua sistem operasional. Inspeksi terakhir lulus.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-PLT-2022-000001',
            'asset_name'   => 'Panel Listrik Utama Workshop',
            'asset_type'   => 'Electrical',
            'location'     => 'Ruang Listrik Workshop',
            'last_checked' => now()->subMonths(5),
            'next_check'   => now()->subMonths(1),
            'condition'    => 'unfit',
            'notes'        => 'Inspeksi terlambat. Jangan dioperasikan sebelum diizinkan tim listrik.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-HYDRANT-2022-000012',
            'asset_name'   => 'Fire Hydrant Post - Masuk Sektor A',
            'asset_type'   => 'Fire Hydrant',
            'location'     => 'Jalan Tambang Masuk Sektor A',
            'last_checked' => now()->subMonths(1),
            'next_check'   => now()->addMonths(5),
            'condition'    => 'good',
            'notes'        => 'Tekanan air normal. Selang dalam kondisi baik.',
        ]);

        QrAsset::create([
            'qr_code'      => 'BBE-BULDZ-2021-000005',
            'asset_name'   => 'Bulldozer D85 - Unit 05',
            'asset_type'   => 'Heavy Equipment',
            'location'     => 'Area Tambang Aktif Sektor C',
            'last_checked' => now()->subDays(15),
            'next_check'   => now()->addMonths(2),
            'condition'    => 'good',
            'notes'        => 'Unit beroperasi normal. Blade dan ripper dalam kondisi baik.',
        ]);

        // ══════════════════════════════════════════════════════════════════
        // NOTIFICATIONS
        // ══════════════════════════════════════════════════════════════════

        Notification::create([
            'user_id' => $faiz->id,
            'type'    => 'hazard',
            'title'   => 'Status Laporan Diperbarui',
            'body'    => 'Laporan "Rambu Keselamatan Kotor" Anda telah diubah menjadi "In Progress" oleh HSE Manager.',
            'data'    => ['report_id' => $r1->id, 'status' => 'in_progress'],
            'status'  => 'read',
        ]);

        Notification::create([
            'user_id' => $demo->id,
            'type'    => 'hazard',
            'title'   => 'Laporan Anda Ditutup',
            'body'    => 'Laporan "Tumpahan Oli Hydraulic" telah ditangani dan ditutup oleh tim maintenance.',
            'data'    => ['report_id' => $r4->id, 'status' => 'closed'],
            'status'  => 'read',
        ]);

        Notification::create([
            'user_id' => $rudi->id,
            'type'    => 'system',
            'title'   => 'Pengingat: Laporan Belum Ditindaklanjuti',
            'body'    => 'Laporan hazard "Kabel Listrik Terbuka" yang Anda buat masih berstatus Open selama 2 hari. Harap hubungi HSE Manager.',
            'data'    => ['report_id' => $r3->id],
            'status'  => 'pending',
        ]);

        Notification::create([
            'user_id' => $faiz->id,
            'type'    => 'announcement',
            'title'   => 'Pengumuman Baru: Pelatihan K3 Wajib',
            'body'    => 'Ada pengumuman baru: Pelatihan K3 Wajib dijadwalkan pada 15 April 2026.',
            'data'    => [],
            'status'  => 'pending',
        ]);

        Notification::create([
            'user_id' => $putri->id,
            'type'    => 'hazard',
            'title'   => 'Status Laporan Diperbarui',
            'body'    => 'Laporan "Pembuangan Limbah B3" Anda sedang ditangani oleh Tim Environmental.',
            'data'    => ['report_id' => $r5->id, 'status' => 'in_progress'],
            'status'  => 'pending',
        ]);

        Notification::create([
            'user_id' => $lintang->id,
            'type'    => 'system',
            'title'   => 'Lisensi Telah Kadaluarsa',
            'body'    => 'Lisensi "Sertifikat Ahli K3 Umum" Anda telah kadaluarsa. Segera perbarui untuk memenuhi syarat operasional.',
            'data'    => ['license_type' => 'Sertifikat Ahli K3 Umum'],
            'status'  => 'pending',
        ]);
    }
}