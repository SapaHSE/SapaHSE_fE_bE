<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_medicals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->date('checkup_date');
            $table->string('blood_type', 10)->nullable();
            $table->string('height', 20)->nullable(); // e.g. "168 cm"
            $table->string('weight', 20)->nullable(); // e.g. "65 kg"
            $table->string('blood_pressure', 20)->nullable(); // e.g. "120/80 mmHg"
            $table->string('allergies')->nullable();
            $table->string('result', 100)->nullable(); // e.g. "Fit to Work"
            $table->date('next_checkup_date')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_medicals');
    }
};
