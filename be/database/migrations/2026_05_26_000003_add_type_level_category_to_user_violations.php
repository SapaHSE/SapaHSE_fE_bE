<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_violations', function (Blueprint $table) {
            $table->string('violation_category', 100)->nullable()->after('title');
            $table->string('violation_subcategory', 100)->nullable()->after('violation_category');
            $table->enum('type', ['Violation', 'Incident'])->default('Violation')->after('violation_subcategory');
            $table->unsignedTinyInteger('level')->default(1)->after('type');
        });
    }

    public function down(): void
    {
        Schema::table('user_violations', function (Blueprint $table) {
            $table->dropColumn([
                'violation_category',
                'violation_subcategory',
                'type',
                'level',
            ]);
        });
    }
};
