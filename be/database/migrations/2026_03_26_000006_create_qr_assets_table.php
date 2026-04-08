<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('qr_assets', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->string('qr_code', 100)->unique();            // Unique QR code (e.g. BBE-APAR-2024-001234)
            $table->string('asset_name', 200);                   // Equipment name
            $table->string('asset_type', 100);                   // Equipment type (e.g. Fire Extinguisher)
            $table->string('location', 200);                     // Asset location
            $table->timestamp('last_checked')->nullable();        // Last inspection date
            $table->timestamp('next_check')->nullable();          // Next scheduled inspection
            $table->enum('condition', ['good', 'needs_attention', 'unfit'])->default('good');
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('qr_assets');
    }
};
