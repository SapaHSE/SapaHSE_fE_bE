<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('read_status', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(\Illuminate\Support\Facades\DB::raw('(UUID())'));
            $table->uuid('user_id');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->uuid('item_id');                             // ID of report or announcement
            $table->enum('item_type', ['report', 'announcement']);
            $table->timestamp('read_at')->useCurrent();

            // Prevent duplicate — 1 user can only read 1 item once
            $table->unique(['user_id', 'item_id', 'item_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('read_status');
    }
};
