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
    Schema::create('checklist_items', function (Blueprint $table) {
        $table->uuid('id')->primary(); 
        $table->uuid('inspection_id');
        $table->string('label');
        $table->boolean('is_checked')->default(false);
        $table->timestamps();
        $table->integer('sort_order')->nullable();

        $table->foreign('inspection_id')
            ->references('id')
            ->on('inspections')
            ->cascadeOnDelete();
    });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('checklist_items');
    }
};
