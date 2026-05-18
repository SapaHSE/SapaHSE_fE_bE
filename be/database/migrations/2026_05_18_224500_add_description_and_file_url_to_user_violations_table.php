<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_violations', function (Blueprint $table) {
            $table->text('description')->nullable()->after('title');
            $table->string('file_url', 255)->nullable()->after('sanction');
        });
    }

    public function down(): void
    {
        Schema::table('user_violations', function (Blueprint $table) {
            $table->dropColumn(['description', 'file_url']);
        });
    }
};
