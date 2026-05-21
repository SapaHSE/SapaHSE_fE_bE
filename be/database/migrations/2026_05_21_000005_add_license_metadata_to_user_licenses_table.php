<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_licenses', function (Blueprint $table) {
            $table->string('license_type', 50)->default('general')->after('license_number');
            $table->string('vehicle_equipment', 150)->nullable()->after('license_type');
            $table->string('sim_type', 10)->nullable()->after('vehicle_equipment');
            $table->string('sim_indonesia_type', 20)->nullable()->after('sim_type');
        });
    }

    public function down(): void
    {
        Schema::table('user_licenses', function (Blueprint $table) {
            $table->dropColumn([
                'license_type',
                'vehicle_equipment',
                'sim_type',
                'sim_indonesia_type',
            ]);
        });
    }
};
