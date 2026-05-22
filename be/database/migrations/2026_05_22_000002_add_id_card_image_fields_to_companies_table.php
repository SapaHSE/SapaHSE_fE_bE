<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            if (! Schema::hasColumn('companies', 'ktt_signature_url')) {
                $table->text('ktt_signature_url')->nullable()->after('logo_url');
            }
            if (! Schema::hasColumn('companies', 'company_stamp_url')) {
                $table->text('company_stamp_url')->nullable()->after('ktt_signature_url');
            }
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            foreach (['company_stamp_url', 'ktt_signature_url'] as $column) {
                if (Schema::hasColumn('companies', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
