<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            if (!Schema::hasColumn('companies', 'radio_label')) {
                $table->string('radio_label', 100)->nullable()->after('ert_freq');
            }
            if (!Schema::hasColumn('companies', 'radio_channel')) {
                $table->string('radio_channel', 100)->nullable()->after('radio_label');
            }
            if (!Schema::hasColumn('companies', 'radio_frequency')) {
                $table->string('radio_frequency', 100)->nullable()->after('radio_channel');
            }
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            foreach (['radio_frequency', 'radio_channel', 'radio_label'] as $column) {
                if (Schema::hasColumn('companies', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
