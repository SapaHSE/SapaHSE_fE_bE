<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{

    public function up(): void
    {
        Schema::table('hazard_reports', function (Blueprint $table) {
            $table->string('pelaku_pelanggaran', 500)->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('hazard_reports', function (Blueprint $table) {
            $table->string('pelaku_pelanggaran', 100)->nullable()->change();
        });
    }
};
