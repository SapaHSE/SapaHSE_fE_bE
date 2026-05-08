<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('report_log_replies', function (Blueprint $table) {
            $table->uuid('parent_reply_id')->nullable()->after('report_log_id');
            $table->foreign('parent_reply_id')
                ->references('id')->on('report_log_replies')
                ->nullOnDelete();
            $table->index('parent_reply_id');
        });
    }

    public function down(): void
    {
        Schema::table('report_log_replies', function (Blueprint $table) {
            $table->dropForeign(['parent_reply_id']);
            $table->dropIndex(['parent_reply_id']);
            $table->dropColumn('parent_reply_id');
        });
    }
};
