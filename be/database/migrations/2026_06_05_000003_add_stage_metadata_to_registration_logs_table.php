<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('registration_logs', function (Blueprint $table) {
            $table->string('registration_status', 50)->nullable();
            $table->string('rejection_stage', 50)->nullable();
            $table->uuid('rejected_by')->nullable();

            $table->foreign('rejected_by')->references('id')->on('users')->nullOnDelete();
            $table->index(['registration_status', 'rejection_stage']);
        });
    }

    public function down(): void
    {
        Schema::table('registration_logs', function (Blueprint $table) {
            $table->dropIndex(['registration_status', 'rejection_stage']);
            $table->dropForeign(['rejected_by']);
            $table->dropColumn([
                'registration_status',
                'rejection_stage',
                'rejected_by',
            ]);
        });
    }
};
