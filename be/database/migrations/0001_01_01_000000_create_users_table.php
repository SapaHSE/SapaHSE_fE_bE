<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->string('nik', 16)->unique();                 // National ID number
            $table->string('employee_id', 20)->unique();         // Company employee ID (e.g. BBE-IT-001)
            $table->string('full_name', 100);
            $table->string('email', 100)->unique();
            $table->string('phone_number', 20)->nullable();
            $table->string('position', 100)->nullable();         // Job title / jabatan
            $table->string('department', 100)->nullable();       // Division / divisi
            $table->string('password', 255);
            $table->text('profile_photo')->nullable();
            $table->boolean('is_active')->default(true);
            $table->enum('role', ['admin', 'supervisor', 'user'])->default('user');
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->uuid('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};