<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if ($this->supportsEnumAlter()) {
            DB::statement("ALTER TABLE hazard_reports MODIFY COLUMN status ENUM('pending', 'open', 'in_progress', 'closed') DEFAULT 'pending'");
            DB::statement("ALTER TABLE inspection_reports MODIFY COLUMN status ENUM('pending', 'open', 'in_progress', 'closed') DEFAULT 'pending'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if ($this->supportsEnumAlter()) {
            DB::statement("ALTER TABLE hazard_reports MODIFY COLUMN status ENUM('open', 'in_progress', 'closed') DEFAULT 'open'");
            DB::statement("ALTER TABLE inspection_reports MODIFY COLUMN status ENUM('open', 'in_progress', 'closed') DEFAULT 'open'");
        }
    }

    private function supportsEnumAlter(): bool
    {
        return in_array(DB::getDriverName(), ['mysql', 'mariadb'], true);
    }
};
