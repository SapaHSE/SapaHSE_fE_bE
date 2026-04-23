<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('tipe_afiliasi', 50)->nullable()->after('company');
            $table->string('perusahaan_kontraktor', 100)->nullable()->after('tipe_afiliasi');
            $table->string('sub_kontraktor', 100)->nullable()->after('perusahaan_kontraktor');
            $table->string('simper', 50)->nullable()->after('sub_kontraktor');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'tipe_afiliasi',
                'perusahaan_kontraktor',
                'sub_kontraktor',
                'simper',
            ]);
        });
    }
};