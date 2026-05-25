<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\HazardReport;
use App\Models\InspectionReport;
use App\Models\ReportLog;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class StatisticsController extends Controller
{
    public function personalStatistics(Request $request)
    {
        $user = Auth::user();
        $userId = $user->id;

        $hQuery = HazardReport::where('user_id', $userId);
        $iQuery = InspectionReport::where('user_id', $userId);

        if ($request->filled('start_date') && $request->filled('end_date')) {
            $hQuery->whereBetween('created_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date . ' 23:59:59'
            ]);
            $iQuery->whereBetween('created_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date . ' 23:59:59'
            ]);
        }

        $hazardIds = (clone $hQuery)->pluck('id');
        $inspectionIds = (clone $iQuery)->pluck('id');

        $hTotal = $hazardIds->count();
        $iTotal = $inspectionIds->count();
        $totalReports = $hTotal + $iTotal;

        $hazardRows = (clone $hQuery)->get(['id', 'status', 'sub_status', 'created_at'])->keyBy('id');
        $inspectionRows = (clone $iQuery)->get(['id', 'status', 'sub_status', 'created_at'])->keyBy('id');

        $allReports = collect()
            ->merge($hazardRows->map(fn($r) => ['type' => 'hazard', 'id' => $r->id, 'status' => $r->status, 'sub_status' => $r->sub_status, 'created_at' => $r->created_at]))
            ->merge($inspectionRows->map(fn($r) => ['type' => 'inspection', 'id' => $r->id, 'status' => $r->status, 'sub_status' => $r->sub_status, 'created_at' => $r->created_at]));

        $accepted = 0;
        $rejected = 0;
        $inProgress = 0;
        $pending = 0;

        foreach ($allReports as $r) {
            $sub = $r['sub_status'] ?? null;
            $status = $r['status'] ?? null;

            if ($sub === 'rejected') {
                $rejected++;
            } elseif ($sub === 'approved' || $sub === 'resolved' || $status === 'closed') {
                $accepted++;
            } elseif ($status === 'in_progress') {
                $inProgress++;
            } else {
                $pending++;
            }
        }

        $accuracy = ($accepted + $rejected) > 0
            ? round(($accepted / ($accepted + $rejected)) * 100, 1)
            : 0.0;

        $streak = $this->calculateStreak($userId, $request);
        $handlingSpeed = $this->calculateHandlingSpeed($hazardIds, $inspectionIds);
        $awards = $this->calculateAwards($userId, $request);
        $needsCategoryAdjustment = $this->countNeedsCategoryAdjustment($userId, $request);

        return response()->json([
            'status' => 'success',
            'data'   => [
                'summary' => [
                    'total'               => $totalReports,
                    'accepted'            => $accepted,
                    'rejected'            => $rejected,
                    'in_progress'         => $inProgress,
                    'pending'             => $pending,
                    'accuracy'            => $accuracy,
                    'streak'              => $streak,
                ],
                'category_accuracy' => [
                    'percentage' => $accuracy,
                    'target'     => 90,
                    'message'    => "Target: 90% - {$needsCategoryAdjustment} laporan perlu penyesuaian kategori bulan ini",
                ],
                'handling_speed' => $handlingSpeed,
                'awards'         => $awards,
                'needs_category_adjustment' => $needsCategoryAdjustment,
            ],
        ]);
    }

    private function calculateStreak(string $userId, Request $request): int
    {
        $hDates = HazardReport::where('user_id', $userId)
            ->selectRaw('DATE(created_at) as report_date')
            ->distinct();
        $iDates = InspectionReport::where('user_id', $userId)
            ->selectRaw('DATE(created_at) as report_date')
            ->distinct();

        if ($request->filled('start_date') && $request->filled('end_date')) {
            $hDates->whereBetween('created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
            $iDates->whereBetween('created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
        }

        $dates = $hDates->union($iDates)
            ->orderBy('report_date', 'desc')
            ->pluck('report_date')
            ->map(fn($d) => Carbon::parse($d))
            ->values();

        if ($dates->isEmpty()) return 0;

        $streak = 0;
        $today = Carbon::today();

        foreach ($dates as $date) {
            $diffFromToday = $today->diffInDays($date, false);

            if ($diffFromToday === $streak) {
                $streak++;
            } elseif ($date->eq($today)) {
                $streak = 1;
            } else {
                break;
            }
        }

        return $streak;
    }

    private function calculateHandlingSpeed($hazardIds, $inspectionIds): array
    {
        $allIds = collect()
            ->merge($hazardIds->map(fn($id) => ['id' => $id, 'type' => HazardReport::class]))
            ->merge($inspectionIds->map(fn($id) => ['id' => $id, 'type' => InspectionReport::class]));

        if ($allIds->isEmpty()) {
            return [
                'avg_validation_minutes' => 0,
                'avg_processing_days'    => 0,
                'avg_total_days'         => 0,
                'avg_validation_label'   => '0 mnt',
                'avg_processing_label'   => '0 hari',
                'avg_total_label'        => '0 hari',
            ];
        }

        $totalValidationMinutes = 0;
        $totalProcessingDays = 0;
        $totalLifecycleDays = 0;
        $validationCount = 0;
        $processingCount = 0;
        $lifecycleCount = 0;

        foreach ($allIds as $item) {
            $report = $item['type']::find($item['id']);
            if (!$report) continue;

            $createdAt = $report->created_at;
            $logs = ReportLog::where('reportable_id', $report->id)
                ->where('reportable_type', $item['type'])
                ->orderBy('created_at')
                ->get();

            if ($logs->isNotEmpty()) {
                $firstLog = $logs->first();
                $validationMinutes = $createdAt->diffInMinutes($firstLog->created_at);
                $totalValidationMinutes += $validationMinutes;
                $validationCount++;

                $lastLog = $logs->last();
                if ($report->status === 'closed') {
                    $totalLifecycleDays += max($createdAt->diffInDays($lastLog->created_at), 1);
                    $lifecycleCount++;
                }
            }

            $approvedLog = $logs->firstWhere('sub_status', 'approved');
            $inProgressLog = $logs->firstWhere('status', 'in_progress');
            if ($approvedLog && $inProgressLog) {
                $days = max($approvedLog->created_at->diffInDays($inProgressLog->created_at), 1);
                $totalProcessingDays += $days;
                $processingCount++;
            }
        }

        $avgValidation = $validationCount > 0
            ? round($totalValidationMinutes / $validationCount)
            : 0;
        $avgProcessing = $processingCount > 0
            ? round($totalProcessingDays / $processingCount, 1)
            : 0;
        $avgTotal = $lifecycleCount > 0
            ? round($totalLifecycleDays / $lifecycleCount, 1)
            : 0;

        return [
            'avg_validation_minutes' => $avgValidation,
            'avg_processing_days'    => $avgProcessing,
            'avg_total_days'         => $avgTotal,
            'avg_validation_label'   => $avgValidation . ' mnt',
            'avg_processing_label'   => $avgProcessing . ' hari',
            'avg_total_label'        => $avgTotal . ' hari',
        ];
    }

    private function calculateAwards(string $userId, Request $request): array
    {
        $hQuery = HazardReport::where('user_id', $userId);
        $iQuery = InspectionReport::where('user_id', $userId);

        if ($request->filled('start_date') && $request->filled('end_date')) {
            $hQuery->whereBetween('created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
            $iQuery->whereBetween('created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
        }

        $monthlyCounts = $hQuery->selectRaw("DATE_FORMAT(created_at, '%Y-%m') as month, COUNT(*) as total")
            ->groupBy('month')
            ->orderBy('total', 'desc')
            ->take(3)
            ->get()
            ->keyBy('month');

        $iMonthly = $iQuery->selectRaw("DATE_FORMAT(created_at, '%Y-%m') as month, COUNT(*) as total")
            ->groupBy('month')
            ->orderBy('total', 'desc')
            ->take(3)
            ->get()
            ->keyBy('month');

        foreach ($iMonthly as $month => $data) {
            if (!isset($monthlyCounts[$month])) {
                $monthlyCounts[$month] = $data;
            } else {
                $monthlyCounts[$month]->total += $data->total;
            }
        }

        $sorted = $monthlyCounts->sortByDesc('total')->take(3);

        $awards = [];
        $monthNames = [
            '01' => 'Jan', '02' => 'Feb', '03' => 'Mar', '04' => 'Apr',
            '05' => 'May', '06' => 'Jun', '07' => 'Jul', '08' => 'Aug',
            '09' => 'Sep', '10' => 'Oct', '11' => 'Nov', '12' => 'Dec',
        ];

        $icons = ['emoji_events', 'local_fire_department', 'bolt'];
        $colors = ['#FFB300', '#FF5722', '#2196F3'];
        $titles = ['Pelapor Terbaik', 'Streak 30 Hari', 'Respon Tercepat'];

        $idx = 0;
        foreach ($sorted as $month => $data) {
            $parts = explode('-', $month);
            $year = $parts[0];
            $mon = $parts[1];
            $label = ($monthNames[$mon] ?? $mon) . ' ' . $year;

            $awards[] = [
                'title' => $titles[$idx] ?? 'Penghargaan',
                'date'  => $label,
                'type'  => $titles[$idx] ?? 'award',
                'icon'  => $icons[$idx] ?? 'emoji_events',
                'color' => $colors[$idx] ?? '#FFB300',
            ];
            $idx++;
            if ($idx >= 3) break;
        }

        return $awards;
    }

    private function countNeedsCategoryAdjustment(string $userId, Request $request): int
    {
        $hQuery = HazardReport::where('user_id', $userId)
            ->where(function ($q) {
                $q->whereNull('hazard_category')
                  ->orWhere('hazard_category', '');
            });

        $iQuery = InspectionReport::where('user_id', $userId)
            ->where(function ($q) {
                $q->whereNull('area')
                  ->orWhere('area', '');
            });

        if ($request->filled('start_date') && $request->filled('end_date')) {
            $hQuery->whereBetween('created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
            $iQuery->whereBetween('created_at', [$request->start_date . ' 00:00:00', $request->end_date . ' 23:59:59']);
        }

        return $hQuery->count() + $iQuery->count();
    }
}
