<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('inspection_reports', function (Blueprint $table) {
            $table->string('reported_department', 100)->nullable()->after('name_inspector');
        });
    }

    public function down(): void
    {
        Schema::table('inspection_reports', function (Blueprint $table) {
            $table->dropColumn('reported_department');
        });
    }
};
