<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_certifications', function (Blueprint $table) {
            $table->date('obtained_at')->nullable()->after('issuer');
            $table->date('expired_at')->nullable()->after('obtained_at');
        });

        DB::statement("
            UPDATE user_certifications
            SET obtained_at = STR_TO_DATE(CONCAT(year, '-01-01'), '%Y-%m-%d')
            WHERE year IS NOT NULL
        ");

        Schema::table('user_certifications', function (Blueprint $table) {
            $table->dropColumn('year');
        });
    }

    public function down(): void
    {
        Schema::table('user_certifications', function (Blueprint $table) {
            $table->integer('year')->nullable()->after('issuer');
        });

        DB::statement("
            UPDATE user_certifications
            SET year = YEAR(obtained_at)
            WHERE obtained_at IS NOT NULL
        ");

        Schema::table('user_certifications', function (Blueprint $table) {
            $table->dropColumn(['obtained_at', 'expired_at']);
        });
    }
};