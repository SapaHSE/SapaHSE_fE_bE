<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;
use Illuminate\Support\Facades\Log;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // Check dan send email untuk notifikasi yang belum dibaca > 3 hari
        // Jalankan setiap hari pada jam yang ditentukan di .env (default: 09:00)
        $schedule->command('notification:check-expired')
            ->dailyAt(config('firebase.notification.check_schedule', '09:00'))
            ->withoutOverlapping()
            ->onFailure(function () {
                Log::error('notification:check-expired command failed');
            })
            ->onSuccess(function () {
                Log::info('notification:check-expired command executed successfully');
            });
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__ . '/Commands');

        require base_path('routes/console.php');
    }
}
