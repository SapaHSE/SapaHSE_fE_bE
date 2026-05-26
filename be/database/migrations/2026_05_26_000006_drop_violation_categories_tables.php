<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('violation_subcategories');
        Schema::dropIfExists('violation_categories');
    }

    public function down(): void
    {
        //
    }
};
