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
        Schema::table('hazard_reports', function (Blueprint $table) {
            $table->string('pelaku_pelanggaran', 100)->nullable()->after('company');
            $table->string('pelapor_location', 200)->nullable()->after('location');
            $table->string('kejadian_location', 200)->nullable()->after('pelapor_location');
            
            // Ubah name_pja menjadi pic_department dengan tipe TEXT
            $table->renameColumn('name_pja', 'pic_department');
        });
        
        // Perlu mengubah tipe kolom secara terpisah karena SQLite dilarang melakukan bareng
        Schema::table('hazard_reports', function (Blueprint $table) {
            $table->text('pic_department')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('hazard_reports', function (Blueprint $table) {
            $table->dropColumn(['pelaku_pelanggaran', 'pelapor_location', 'kejadian_location']);
            $table->renameColumn('pic_department', 'name_pja');
        });
        
        Schema::table('hazard_reports', function (Blueprint $table) {
            $table->string('name_pja', 100)->nullable()->change();
        });
    }
};