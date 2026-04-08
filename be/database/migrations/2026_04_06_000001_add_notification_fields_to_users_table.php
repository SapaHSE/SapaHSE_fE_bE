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
        Schema::table('users', function (Blueprint $table) {
            // FCM token untuk push notification
            $table->string('fcm_token')->nullable()->after('profile_photo');
            
            // Tracking kapan user terakhir active
            $table->timestamp('last_activity_at')->nullable()->after('fcm_token');
            
            // Tracking kapan notification terakhir dikirim
            $table->timestamp('last_notification_sent_at')->nullable()->after('last_activity_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['fcm_token', 'last_activity_at', 'last_notification_sent_at']);
        });
    }
};
