<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->uuid('hrd_reviewed_by')->nullable();
            $table->timestamp('hrd_reviewed_at')->nullable();
            $table->uuid('admin_reviewed_by')->nullable();
            $table->timestamp('admin_reviewed_at')->nullable();

            $table->foreign('hrd_reviewed_by')->references('id')->on('users')->nullOnDelete();
            $table->foreign('admin_reviewed_by')->references('id')->on('users')->nullOnDelete();
            $table->index('registration_status');
        });

        DB::table('users')
            ->where('registration_status', 'pending')
            ->update(['registration_status' => 'pending_hrd']);
    }

    public function down(): void
    {
        DB::table('users')
            ->where('registration_status', 'pending_hrd')
            ->update(['registration_status' => 'pending']);

        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['registration_status']);
            $table->dropForeign(['hrd_reviewed_by']);
            $table->dropForeign(['admin_reviewed_by']);
            $table->dropColumn([
                'hrd_reviewed_by',
                'hrd_reviewed_at',
                'admin_reviewed_by',
                'admin_reviewed_at',
            ]);
        });
    }
};
