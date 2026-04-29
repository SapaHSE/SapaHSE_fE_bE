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
        Schema::create('registration_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('full_name');
            $table->string('employee_id');
            $table->string('personal_email');
            $table->string('phone_number', 20)->nullable();
            $table->string('company')->nullable();
            $table->string('department')->nullable();
            $table->string('rejection_reason')->nullable();
            $table->timestamp('rejected_at')->useCurrent();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('registration_logs');
    }
};