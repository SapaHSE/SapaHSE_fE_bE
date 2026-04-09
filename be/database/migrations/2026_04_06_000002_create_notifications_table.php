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
        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary(); // atau uuid
            
            // Referensi user
            $table->uuid('user_id');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            
            // Tipe notifikasi (inspection, announcement, report, dll)
            $table->string('type');
            
            // Judul dan isi
            $table->string('title');
            $table->text('body');
            
            // Data tambahan (JSON)
            $table->json('data')->nullable();
            
            // Status notifikasi
            $table->enum('status', ['pending', 'sent_push', 'sent_email', 'read'])->default('pending');
            
            // Tracking
            $table->timestamp('pushed_at')->nullable();
            $table->timestamp('emailed_at')->nullable();
            $table->timestamp('read_at')->nullable();
            
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
