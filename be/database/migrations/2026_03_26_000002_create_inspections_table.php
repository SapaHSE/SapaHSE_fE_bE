<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inspections', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->uuid('user_id');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->string('title', 200);
            $table->string('area', 100);                         // Work area (e.g. Mining Area Sector B)
            $table->string('location', 200);                     // Specific location
            $table->string('inspector_name', 100);               // Name of inspector
            $table->enum('result', ['compliant', 'non_compliant', 'needs_follow_up'])->default('compliant');
            $table->text('notes')->nullable();
            $table->text('image_url')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('checklist_items');
        Schema::dropIfExists('inspections');
    }
};
