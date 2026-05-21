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
        if (!Schema::hasColumn('areas', 'pic_user_ids')) {
            Schema::table('areas', function (Blueprint $table) {
                $table->json('pic_user_ids')->nullable()->after('pic_user_id');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasColumn('areas', 'pic_user_ids')) {
            Schema::table('areas', function (Blueprint $table) {
                $table->dropColumn('pic_user_ids');
            });
        }
    }
};
