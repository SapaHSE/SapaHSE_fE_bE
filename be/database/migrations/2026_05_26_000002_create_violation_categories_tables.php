<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('violation_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('code', 50)->nullable();
            $table->timestamps();
        });

        Schema::create('violation_subcategories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained('violation_categories')->onDelete('cascade');
            $table->string('name');
            $table->string('abbreviation', 50)->nullable();
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('violation_subcategories');
        Schema::dropIfExists('violation_categories');
    }
};
