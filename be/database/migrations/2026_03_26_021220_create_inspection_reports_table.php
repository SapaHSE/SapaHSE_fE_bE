<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('inspection_reports', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->string('ticket_number', 30)->unique()->nullable();
            $table->uuid('user_id');
            $table->string('title', 200);
            $table->text('description');
            $table->enum('status', ['open', 'in_progress', 'closed'])->default('open');
            $table->string('sub_status', 50)->nullable();
            $table->string('location', 200);
            $table->text('image_url')->nullable();
            
            // Inspection-specific
            $table->string('area', 100)->nullable();
            $table->string('name_inspector', 150)->nullable();
            $table->text('notes')->nullable();
            $table->enum('result', ['compliant', 'non_compliant', 'needs_follow_up'])->nullable();

            $table->timestamps();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inspection_reports');
    }
};