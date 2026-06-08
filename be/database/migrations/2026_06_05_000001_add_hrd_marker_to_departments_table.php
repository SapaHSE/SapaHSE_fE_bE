<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('departments', function (Blueprint $table) {
            $table->boolean('is_hrd')->default(false)->index();
        });

        DB::table('departments')
            ->whereRaw('LOWER(TRIM(name)) IN (?, ?)', ['human resources', 'hrd'])
            ->update(['is_hrd' => true]);
    }

    public function down(): void
    {
        Schema::table('departments', function (Blueprint $table) {
            $table->dropIndex(['is_hrd']);
            $table->dropColumn('is_hrd');
        });
    }
};
