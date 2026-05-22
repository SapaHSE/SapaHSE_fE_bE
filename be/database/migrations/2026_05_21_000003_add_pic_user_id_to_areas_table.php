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
        if (!Schema::hasColumn('areas', 'pic_user_id')) {
            Schema::table('areas', function (Blueprint $table) {
                $table->uuid('pic_user_id')->nullable()->after('code');
                $table->foreign('pic_user_id')
                    ->references('id')
                    ->on('users')
                    ->nullOnDelete();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasColumn('areas', 'pic_user_id')) {
            Schema::table('areas', function (Blueprint $table) {
                $table->dropForeign(['pic_user_id']);
                $table->dropColumn('pic_user_id');
            });
        }
    }
};
