<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // MySQL does not support adding values to ENUM via standard Schema builder,
        // so we use raw ALTER statements.
        if (DB::getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE user_licenses MODIFY COLUMN approval_status ENUM('pending', 'approved', 'rejected', 'pending_changes') NOT NULL DEFAULT 'pending'");
            DB::statement("ALTER TABLE user_certifications MODIFY COLUMN approval_status ENUM('pending', 'approved', 'rejected', 'pending_changes') NOT NULL DEFAULT 'pending'");
        }
    }

    public function down(): void
    {
        // Revert: remove 'pending_changes' from both columns.
        if (DB::getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE user_licenses MODIFY COLUMN approval_status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending'");
            DB::statement("ALTER TABLE user_certifications MODIFY COLUMN approval_status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending'");
        }
    }
};
