<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('news', function (Blueprint $table) {
            $table->boolean('published_notified')->default(false)->after('publish_date');
        });

        // Backfill: anything already published in past is considered notified.
        DB::statement('UPDATE news SET published_notified = 1 WHERE publish_date <= CURDATE()');
    }

    public function down(): void
    {
        Schema::table('news', function (Blueprint $table) {
            $table->dropColumn('published_notified');
        });
    }
};
