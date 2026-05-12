<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (
            ! Schema::hasTable('user_violations')
            || Schema::hasColumn('user_violations', 'expired_at')
        ) {
            return;
        }

        Schema::table('user_violations', function (Blueprint $table) {
            $table->date('expired_at')->nullable()->after('date_of_violation');
        });
    }

    public function down(): void
    {
        if (
            ! Schema::hasTable('user_violations')
            || ! Schema::hasColumn('user_violations', 'expired_at')
        ) {
            return;
        }

        Schema::table('user_violations', function (Blueprint $table) {
            $table->dropColumn('expired_at');
        });
    }
};
