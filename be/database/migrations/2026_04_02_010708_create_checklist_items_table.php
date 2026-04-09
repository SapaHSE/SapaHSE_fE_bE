<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('checklist_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('report_id');                     // FK → reports (was inspection_id)
            $table->string('label');
            $table->boolean('is_checked')->default(false);
            $table->integer('sort_order')->nullable();
            $table->timestamps();

            $table->foreign('report_id')
                ->references('id')
                ->on('reports')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('checklist_items');
    }
};
