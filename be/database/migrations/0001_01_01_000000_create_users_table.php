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
            $table->string('employee_id', 50)->unique();                // Staff / Employee ID (free format, e.g. BBE-IT-001)
            $table->string('full_name', 100);
            $table->string('personal_email', 150)->unique();         // Personal email — used for login & email verification
            $table->string('work_email', 150)->nullable()->unique();  // Work / office email (optional)
            $table->string('phone_number', 20)->nullable();
            $table->string('position', 100)->nullable();              // Job title / jabatan
            $table->string('department', 100)->nullable();            // Division / divisi
            $table->string('company', 100)->nullable();               // Company / perusahaan
            $table->string('password_hash', 255);
            $table->text('profile_photo')->nullable();
            $table->boolean('is_active')->default(true);
            $table->enum('role', ['superadmin', 'admin', 'user'])->default('user');
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