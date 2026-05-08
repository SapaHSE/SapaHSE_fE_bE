<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('report_log_replies', function (Blueprint $table) {
            $table->json('attachment_urls')->nullable()->after('attachment_url');
        });
    }

    public function down(): void
    {
        Schema::table('report_log_replies', function (Blueprint $table) {
            $table->dropColumn('attachment_urls');
        });
    }
};
