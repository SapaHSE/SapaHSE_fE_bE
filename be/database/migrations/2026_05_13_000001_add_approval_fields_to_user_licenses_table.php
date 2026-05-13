<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_licenses', function (Blueprint $table) {
            $table->enum('approval_status', ['pending', 'approved', 'rejected'])
                ->default('pending')
                ->after('is_verified');
            $table->text('rejection_reason')->nullable()->after('approval_status');
            $table->uuid('reviewed_by')->nullable()->after('rejection_reason');
            $table->timestamp('reviewed_at')->nullable()->after('reviewed_by');
            $table->timestamp('submitted_at')->nullable()->after('reviewed_at');

            $table->foreign('reviewed_by')->references('id')->on('users')->nullOnDelete();
            $table->index('approval_status');
        });

        // Data legacy: semua row existing wajib direview ulang.
        DB::statement("
            UPDATE user_licenses
            SET approval_status = 'pending',
                is_verified = 0,
                submitted_at = COALESCE(submitted_at, created_at),
                rejection_reason = NULL,
                reviewed_by = NULL,
                reviewed_at = NULL
        ");
    }

    public function down(): void
    {
        Schema::table('user_licenses', function (Blueprint $table) {
            $table->dropForeign(['reviewed_by']);
            $table->dropIndex(['approval_status']);
            $table->dropColumn([
                'approval_status',
                'rejection_reason',
                'reviewed_by',
                'reviewed_at',
                'submitted_at',
            ]);
        });
    }
};
