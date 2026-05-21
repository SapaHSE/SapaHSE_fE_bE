<?php

namespace App\Console\Commands;

use App\Models\News;
use App\Services\NotificationService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class PublishScheduledNews extends Command
{
    protected $signature = 'news:publish-scheduled';

    protected $description = 'Fire push notifications for news whose publish_date has arrived';

    public function handle(NotificationService $notificationService): int
    {
        $today = now()->toDateString();

        $due = News::where('is_active', true)
            ->where('published_notified', false)
            ->whereDate('publish_date', '<=', $today)
            ->get();

        if ($due->isEmpty()) {
            $this->info('No scheduled news due for publishing.');
            return Command::SUCCESS;
        }

        $this->info("Found {$due->count()} scheduled article(s) due. Firing notifications...");

        $sent = 0;
        foreach ($due as $news) {
            try {
                $notificationService->sendPushToAll(
                    'Berita HSE Baru',
                    $news->title,
                    ['news_id' => $news->id, 'type' => 'news']
                );

                $news->update(['published_notified' => true]);
                $sent++;
                $this->line("  ✓ {$news->title}");
            } catch (\Exception $e) {
                Log::error("Gagal broadcast scheduled news {$news->id}: " . $e->getMessage());
                $this->error("  ✗ {$news->title} — {$e->getMessage()}");
            }
        }

        $this->info("Done. {$sent}/{$due->count()} notification(s) sent.");
        return Command::SUCCESS;
    }
}
