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
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->string('title', 200);
            $table->text('description');
            $table->enum('type', ['hazard', 'inspection'])->default('hazard');
            $table->enum('severity', ['low', 'medium', 'high'])->default('low');
            $table->enum('status', ['open', 'in_progress', 'closed'])->default('open');
            $table->string('location', 200);
            $table->string('name_pja', 100)->nullable();         // Penanggung Jawab Area
            $table->string('reported_department', 100)->nullable(); // Department yang dilaporkan
            $table->text('image_url')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};