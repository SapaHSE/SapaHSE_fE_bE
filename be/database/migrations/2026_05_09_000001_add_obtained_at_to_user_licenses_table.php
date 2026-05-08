<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_licenses', function (Blueprint $table) {
            $table->date('obtained_at')->nullable()->after('license_number');
            $table->date('expired_at')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('user_licenses', function (Blueprint $table) {
            $table->dropColumn('obtained_at');
            $table->date('expired_at')->nullable(false)->change();
        });
    }
};