<?php

namespace App\Console\Commands;

use App\Services\NotificationService;
use Illuminate\Console\Command;

class CheckExpiredNotifications extends Command
{
    protected $signature = 'notification:check-expired';

    protected $description = 'Check dan send email untuk notifikasi yang belum dibaca > 3 hari';

    public function handle(NotificationService $notificationService): int
    {
        $this->info('Memulai check notifikasi yang expired...');

        try {
            $sent = $notificationService->checkAndSendEmailForExpiredNotifications();

            $this->info("✓ Berhasil mengirim {$sent} email reminder");

            return Command::SUCCESS;
        } catch (\Exception $e) {
            $this->error('Error: ' . $e->getMessage());
            return Command::FAILURE;
        }
    }
}
