<?php

use App\Models\HazardReport;
use App\Models\InspectionReport;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Normalize legacy pending reports to open + validating.
        DB::table('hazard_reports')
            ->where('status', 'pending')
            ->where(function ($q) {
                $q->whereNull('sub_status')->orWhere('sub_status', '');
            })
            ->update(['sub_status' => 'validating']);

        DB::table('inspection_reports')
            ->where('status', 'pending')
            ->where(function ($q) {
                $q->whereNull('sub_status')->orWhere('sub_status', '');
            })
            ->update(['sub_status' => 'validating']);

        DB::table('hazard_reports')
            ->where('status', 'pending')
            ->update(['status' => 'open']);

        DB::table('inspection_reports')
            ->where('status', 'pending')
            ->update(['status' => 'open']);

        // Keep report logs aligned with the new main status domain.
        DB::table('report_logs')
            ->where('status', 'pending')
            ->whereIn('reportable_type', [HazardReport::class, InspectionReport::class])
            ->update(['status' => 'open']);

        if ($this->supportsEnumAlter()) {
            DB::statement("ALTER TABLE hazard_reports MODIFY COLUMN status ENUM('open', 'in_progress', 'closed') DEFAULT 'open'");
            DB::statement("ALTER TABLE inspection_reports MODIFY COLUMN status ENUM('open', 'in_progress', 'closed') DEFAULT 'open'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if ($this->supportsEnumAlter()) {
            DB::statement("ALTER TABLE hazard_reports MODIFY COLUMN status ENUM('pending', 'open', 'in_progress', 'closed') DEFAULT 'pending'");
            DB::statement("ALTER TABLE inspection_reports MODIFY COLUMN status ENUM('pending', 'open', 'in_progress', 'closed') DEFAULT 'pending'");
        }
    }

    private function supportsEnumAlter(): bool
    {
        return in_array(DB::getDriverName(), ['mysql', 'mariadb'], true);
    }
};
