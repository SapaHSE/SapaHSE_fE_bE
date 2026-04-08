<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('news', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->uuid('created_by');
            $table->foreign('created_by')->references('id')->on('users')->onDelete('cascade');
            $table->string('title', 300);
            $table->text('excerpt')->nullable();                  // Short summary
            $table->text('content');
            $table->string('category', 50);                      // e.g. K3/HSE, Operational, Regulation, Achievement
            $table->string('author_name', 100)->nullable();       // Display name of author
            $table->text('image_url')->nullable();
            $table->boolean('is_featured')->default(false);      // Show in carousel
            $table->boolean('is_active')->default(true);         // Published status
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('news');
    }
};