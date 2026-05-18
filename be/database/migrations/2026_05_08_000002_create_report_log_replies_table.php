<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('report_log_replies', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('report_log_id');
            $table->uuid('parent_reply_id')->nullable();
            $table->uuid('user_id');
            $table->text('message');
            $table->string('attachment_url', 500)->nullable();
            $table->json('attachment_urls')->nullable();
            $table->timestamps();

            $table->foreign('report_log_id')->references('id')->on('report_logs')->cascadeOnDelete();
            $table->foreign('parent_reply_id')->references('id')->on('report_log_replies')->nullOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['report_log_id', 'created_at']);
            $table->index('parent_reply_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('report_log_replies');
    }
};
