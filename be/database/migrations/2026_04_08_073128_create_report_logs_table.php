<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('report_logs', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->uuid('reportable_id');
            $table->string('reportable_type');
            $table->uuid('user_id')->nullable();                          // user yang mengupdate
            $table->uuid('tagged_user_id')->nullable();       // user yang di-tag (opsional, hanya admin/superadmin)
            $table->string('status', 50);                     // e.g. 'open', 'in_progress', 'closed'
            $table->string('sub_status', 50)->nullable();
            $table->text('message')->nullable();              // deskripsi update/pesan
            $table->text('image_url')->nullable();            // bukti foto
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('set null');
            $table->foreign('tagged_user_id')->references('id')->on('users')->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('report_logs');
    }
};