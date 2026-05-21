<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->text('logo_url')->nullable()->after('code');
            $table->foreignUuid('ktt_user_id')
                ->nullable()
                ->after('logo_url')
                ->constrained('users')
                ->nullOnDelete();
            $table->string('emergency_number', 50)->nullable()->after('ktt_user_id');
            $table->string('ert_freq', 100)->nullable()->after('emergency_number');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropForeign(['ktt_user_id']);
            $table->dropColumn([
                'logo_url',
                'ktt_user_id',
                'emergency_number',
                'ert_freq',
            ]);
        });
    }
};
