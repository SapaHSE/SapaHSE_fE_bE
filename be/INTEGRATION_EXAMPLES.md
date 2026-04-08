# Integration Examples

Contoh cara mengintegrasikan Notification System dengan existing features.

## 1. Send Notification saat Report baru dibuat

### Update ReportController

```php
use App\Services\NotificationService;

class ReportController extends Controller
{
    public function store(Request $request, NotificationService $notificationService)
    {
        $validated = $request->validate([
            'title' => 'required|string',
            'description' => 'required|string',
            'priority' => 'required|in:low,medium,high,critical',
            // ... other validations
        ]);

        $report = Report::create([
            'user_id' => auth()->id(),
            ...$validated,
        ]);

        // Notify supervisors/admins tentang report baru
        $supervisors = User::where('role', 'admin')
            ->orWhere('role', 'supervisor')
            ->where('is_active', true)
            ->get();

        foreach ($supervisors as $supervisor) {
            $notificationService->createNotification(
                user: $supervisor,
                type: 'report',
                title: 'Laporan Hazard Baru',
                body: "Report baru dari " . auth()->user()->full_name . ": " . $report->title,
                data: [
                    'report_id' => $report->id,
                    'reporter_id' => auth()->id(),
                    'priority' => $report->priority,
                    'url' => "/reports/{$report->id}",
                ]
            );
        }

        return response()->json([
            'message' => 'Report berhasil dibuat',
            'data' => $report,
        ], 201);
    }
}
```

## 2. Send Notification saat Status Report berubah

### Update ReportController - updateStatus method

```php
public function updateStatus(Request $request, Report $report, NotificationService $notificationService)
{
    $validated = $request->validate([
        'status' => 'required|in:open,in_progress,closed,rejected',
        'comment' => 'nullable|string',
    ]);

    $oldStatus = $report->status;
    $report->update($validated);

    // Notify reporter tentang status change
    $notificationService->createNotification(
        user: $report->user,
        type: 'report_status_updated',
        title: 'Status Report Diperbarui',
        body: "Report Anda '{$report->title}' status berubah dari {$oldStatus} → {$report->status}",
        data: [
            'report_id' => $report->id,
            'old_status' => $oldStatus,
            'new_status' => $report->status,
            'comment' => $request->comment,
            'url' => "/reports/{$report->id}",
        ]
    );

    return response()->json([
        'message' => 'Status report berhasil diupdate',
        'data' => $report,
    ]);
}
```

## 3. Send Notification saat Inspection dibuat

### Update InspectionController

```php
public function store(Request $request, NotificationService $notificationService)
{
    $validated = $request->validate([
        'location' => 'required|string',
        'type' => 'required|in:routine,follow_up,incident',
        'checklist_items' => 'required|array|min:1',
        // ... other validations
    ]);

    $inspection = Inspection::create([
        'user_id' => auth()->id(),
        ...$validated,
    ]);

    // Save checklist items
    foreach ($request->checklist_items as $item) {
        ChecklistItem::create([
            'inspection_id' => $inspection->id,
            'description' => $item['description'],
        ]);
    }

    // Notify team members tentang inspection baru
    $teamMembers = User::where('department', auth()->user()->department)
        ->where('id', '!=', auth()->id())
        ->where('is_active', true)
        ->get();

    foreach ($teamMembers as $member) {
        $notificationService->createNotification(
            user: $member,
            type: 'inspection',
            title: 'Inspeksi Baru - ' . $inspection->location,
            body: "Inspeksi baru dari " . auth()->user()->full_name . " di lokasi " . $inspection->location,
            data: [
                'inspection_id' => $inspection->id,
                'location' => $inspection->location,
                'type' => $inspection->type,
                'url' => "/inspections/{$inspection->id}",
            ]
        );
    }

    return response()->json([
        'message' => 'Inspeksi berhasil dibuat',
        'data' => $inspection,
    ], 201);
}
```

## 4. Send Notification saat Announcement dibuat

### Update AnnouncementController

```php
public function store(Request $request, NotificationService $notificationService)
{
    $validated = $request->validate([
        'title' => 'required|string',
        'content' => 'required|string',
        'priority' => 'nullable|in:low,medium,high',
    ]);

    $announcement = Announcement::create([
        'created_by' => auth()->id(),
        ...$validated,
    ]);

    // Notify semua user tentang announcement baru
    $allUsers = User::where('is_active', true)
        ->where('id', '!=', auth()->id())
        ->get();

    foreach ($allUsers as $user) {
        $notificationService->createNotification(
            user: $user,
            type: 'announcement',
            title: 'Pengumuman: ' . $announcement->title,
            body: $announcement->content,
            data: [
                'announcement_id' => $announcement->id,
                'priority' => $announcement->priority,
                'url' => "/announcements/{$announcement->id}",
            ]
        );
    }

    return response()->json([
        'message' => 'Pengumuman berhasil dibuat',
        'data' => $announcement,
    ], 201);
}
```

## 5. Send Notification saat News dibuat

### Update NewsController

```php
public function store(Request $request, NotificationService $notificationService)
{
    $validated = $request->validate([
        'title' => 'required|string',
        'content' => 'required|string',
        'category' => 'required|string',
    ]);

    $news = News::create([
        'created_by' => auth()->id(),
        ...$validated,
    ]);

    // Notify all active users
    $allUsers = User::where('is_active', true)
        ->where('id', '!=', auth()->id())
        ->get();

    foreach ($allUsers as $user) {
        $notificationService->createNotification(
            user: $user,
            type: 'news',
            title: 'Berita Baru: ' . $news->title,
            body: substr($news->content, 0, 100) . '...',
            data: [
                'news_id' => $news->id,
                'category' => $news->category,
                'url' => "/news/{$news->id}",
            ]
        );
    }

    return response()->json([
        'message' => 'Berita berhasil dibuat',
        'data' => $news,
    ], 201);
}
```

## 6. Middleware untuk Auto Update Activity

Buat middleware untuk otomatis update last_activity setiap request ke API yang authenticated.

### Create Middleware

```bash
php artisan make:middleware UpdateUserActivity
```

### Update Middleware

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Services\NotificationService;

class UpdateUserActivity extends Middleware
{
    public function handle(Request $request, Closure $next, NotificationService $notificationService)
    {
        if (auth()->check()) {
            $notificationService->updateLastActivity(auth()->user());
        }

        return $next($request);
    }
}
```

### Register di Kernel

```php
// app/Http/Kernel.php

protected $middlewareGroups = [
    'api' => [
        // ... existing middleware
        \App\Http\Middleware\UpdateUserActivity::class,
    ],
];
```

## 7. Event-based Notifications (Advanced)

Untuk yang lebih advanced, bisa menggunakan Laravel Events.

### Create Notification Event

```bash
php artisan make:event ReportCreated
```

### Update Event

```php
<?php

namespace App\Events;

use App\Models\Report;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ReportCreated
{
    use Dispatchable, SerializesModels;

    public function __construct(public Report $report)
    {
    }
}
```

### Create Listener

```bash
php artisan make:listener SendReportNotification --event=ReportCreated
```

### Update Listener

```php
<?php

namespace App\Listeners;

use App\Events\ReportCreated;
use App\Services\NotificationService;
use App\Models\User;

class SendReportNotification
{
    public function __construct(protected NotificationService $notificationService)
    {
    }

    public function handle(ReportCreated $event): void
    {
        $supervisors = User::where('role', 'admin')
            ->orWhere('role', 'supervisor')
            ->where('is_active', true)
            ->get();

        foreach ($supervisors as $supervisor) {
            $this->notificationService->createNotification(
                user: $supervisor,
                type: 'report',
                title: 'Laporan Hazard Baru',
                body: "Report baru dari " . $event->report->user->full_name,
                data: [
                    'report_id' => $event->report->id,
                ]
            );
        }
    }
}
```

### Register Listener di EventServiceProvider

```php
<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use App\Events\ReportCreated;
use App\Listeners\SendReportNotification;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        ReportCreated::class => [
            SendReportNotification::class,
        ],
    ];
}
```

### Update Controller untuk dispatch Event

```php
public function store(Request $request)
{
    $report = Report::create([...]);
    
    // Dispatch event
    ReportCreated::dispatch($report);
    
    return response()->json($report, 201);
}
```

## 8. Model Observer (Alternative untuk Event)

Atau bisa gunakan Model Observer yang lebih sederhana:

### Create Observer

```bash
php artisan make:observer ReportObserver --model=Report
```

### Update Observer

```php
<?php

namespace App\Observers;

use App\Models\Report;
use App\Services\NotificationService;
use App\Models\User;

class ReportObserver
{
    public function __construct(protected NotificationService $notificationService)
    {
    }

    public function created(Report $report): void
    {
        $supervisors = User::where('role', 'admin')
            ->orWhere('role', 'supervisor')
            ->get();

        foreach ($supervisors as $supervisor) {
            $this->notificationService->createNotification(
                user: $supervisor,
                type: 'report',
                title: 'Laporan Hazard Baru',
                body: "Report baru dari " . $report->user->full_name,
                data: ['report_id' => $report->id]
            );
        }
    }

    public function updated(Report $report): void
    {
        if ($report->isDirty('status')) {
            $this->notificationService->createNotification(
                user: $report->user,
                type: 'report_status_updated',
                title: 'Status Report Diperbarui',
                body: "Status report Anda berubah menjadi {$report->status}",
                data: ['report_id' => $report->id]
            );
        }
    }
}
```

### Register Observer di AppServiceProvider

```php
<?php

namespace App\Providers;

use App\Models\Report;
use App\Observers\ReportObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Report::observe(ReportObserver::class);
    }
}
```

## Testing Integrasi

### Test Report Notification

```bash
php artisan tinker

>>> $user = User::first();
>>> auth()->login($user);
>>> $report = \App\Models\Report::create([
...   'user_id' => auth()->id(),
...   'title' => 'Test Report',
...   'description' => 'Test',
...   'priority' => 'high'
... ]);

>>> // Check dass notifications dibuat untuk supervisors
>>> \App\Models\Notification::latest()->get();
```

## Best Practices

1. **Jangan block main flow** - Pertimbangkan menggunakan jobs untuk send notification async
2. **Set proper permissions** - Validasi user benar punya akses ke notification
3. **Handle missing tokens** - Graceful handling jika FCM token sudah expired
4. **Log everything** - Monitor notification delivery via logs
5. **Test notifications** - Setup automated tests untuk notification system
6. **Rate limiting** - Jangan spam user dengan terlalu banyak notifikasi
7. **User preferences** - Ijinkan user memilih notifikasi apa yang ingin diterima

## Next Steps

1. Integrate notification dengan semua existing features
2. Add notification preferences per user
3. Setup proper error handling dan retry logic
4. Add notification categories/grouping di mobile app
5. Monitor notification delivery metrics
