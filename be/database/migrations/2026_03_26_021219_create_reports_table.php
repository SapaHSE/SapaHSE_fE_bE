<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reports', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->uuid('user_id');
            $table->enum('type', ['hazard', 'inspection'])->default('hazard');
            $table->string('title', 200);
            $table->text('description');
            $table->enum('status', ['open', 'in_progress', 'closed'])->default('open');
            $table->string('sub_status', 50)->nullable();
            $table->string('location', 200);
            $table->text('image_url')->nullable();

            // ── Hazard-only (nullable when type=inspection) ────────────────────
            $table->enum('severity', ['low', 'medium', 'high'])->nullable();
            $table->string('name_pja', 100)->nullable();
            $table->string('reported_department', 100)->nullable();

            // ── Inspection-only (nullable when type=hazard) ────────────────────
            $table->string('area', 100)->nullable();
            $table->string('notes', 100)->nullable();
            $table->enum('result', ['compliant', 'non_compliant', 'needs_follow_up'])->nullable();

            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};