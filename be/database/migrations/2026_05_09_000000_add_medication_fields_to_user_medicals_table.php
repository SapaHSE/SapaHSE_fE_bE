<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_medicals', function (Blueprint $table) {
            $table->string('last_medication', 255)->nullable()->after('allergies');
            $table->string('current_medication', 255)->nullable()->after('last_medication');
            $table->string('current_illness', 500)->nullable()->after('current_medication');
        });
    }

    public function down(): void
    {
        Schema::table('user_medicals', function (Blueprint $table) {
            $table->dropColumn(['last_medication', 'current_medication', 'current_illness']);
        });
    }
};