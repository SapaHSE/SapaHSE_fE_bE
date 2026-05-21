<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'simper')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('simper', 50)->nullable()->after('sub_kontraktor');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('users', 'simper')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('simper');
            });
        }
    }
};
