<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\HazardReport;
use App\Models\InspectionReport;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    /**
     * Get aggregate statistics for Hazard and Inspection reports
     */
    public function statistics(Request $request)
    {
        // ── 1. Hazard Statistics ─────────────────────────────────────────────
        $hQuery = HazardReport::query();
        
        if ($request->filled('start_date') && $request->filled('end_date')) {
            $hQuery->whereBetween('created_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date . ' 23:59:59'
            ]);
        }

        $hStats = [
            'total'       => $hQuery->count(),
            'open'        => (clone $hQuery)->where('status', 'open')->count(),
            'in_progress' => (clone $hQuery)->where('status', 'in_progress')->count(),
            'closed'      => (clone $hQuery)->where('status', 'closed')->count(),
            'severity' => [
                'critical' => (clone $hQuery)->where('severity', 'critical')->count(),
                'high'     => (clone $hQuery)->where('severity', 'high')->count(),
                'low'      => (clone $hQuery)->where('severity', 'low')->count(),
            ]
        ];

        // ── 2. Inspection Statistics ─────────────────────────────────────────
        $iQuery = InspectionReport::query();

        if ($request->filled('start_date') && $request->filled('end_date')) {
            $iQuery->whereBetween('created_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date . ' 23:59:59'
            ]);
        }

        $iStats = [
            'total'       => $iQuery->count(),
            'open'        => (clone $iQuery)->where('status', 'open')->count(),
            'in_progress' => (clone $iQuery)->where('status', 'in_progress')->count(),
            'closed'      => (clone $iQuery)->where('status', 'closed')->count(),
            'results' => [
                'compliant'         => (clone $iQuery)->where('result', 'compliant')->count(),
                'non_compliant'     => (clone $iQuery)->where('result', 'non_compliant')->count(),
                'needs_follow_up'   => (clone $iQuery)->where('result', 'needs_follow_up')->count(),
            ]
        ];

        // ── 3. Weekly Trend (Last 7 Days) ───────────────────────────────────
        $weeklyTrend = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = now()->subDays($i)->format('Y-m-d');
            
            $hazardCount = HazardReport::whereDate('created_at', $date)->count();
            $inspectionCount = InspectionReport::whereDate('created_at', $date)->count();
            
            $weeklyTrend[] = [
                'day'        => now()->subDays($i)->isoFormat('dddd'),
                'date'       => $date,
                'hazard'     => $hazardCount,
                'inspection' => $inspectionCount,
                'total'      => $hazardCount + $inspectionCount,
            ];
        }

        // ── 4. Latest Activities (Merged) ───────────────────────────────────
        $latestHazards = HazardReport::orderBy('created_at', 'desc')->limit(5)->get()->map(fn($h) => [
            'type'      => 'hazard',
            'id'        => $h->id,
            'title'     => $h->title,
            'severity'  => $h->severity,
            'status'    => $h->status,
            'user'      => $h->user->full_name ?? 'Unknown',
            'timestamp' => $h->created_at->diffForHumans(),
        ]);

        $latestInspections = InspectionReport::orderBy('created_at', 'desc')->limit(5)->get()->map(fn($i) => [
            'type'      => 'inspection',
            'id'        => $i->id,
            'title'     => $i->title,
            'result'    => $i->result,
            'status'    => $i->status,
            'user'      => $i->user->full_name ?? 'Unknown',
            'timestamp' => $i->created_at->diffForHumans(),
        ]);

        $latestActivities = $latestHazards->concat($latestInspections)
            ->sortByDesc('timestamp')
            ->take(5)
            ->values();

        // ── 5. Monthly Trend (Current Year) ────────────────────────────────
        $monthlyTrend = [];
        $currentYear = now()->year;
        for ($m = 1; $m <= 12; $m++) {
            $monthName = \Carbon\Carbon::create($currentYear, $m, 1)->isoFormat('MMMM');
            
            $hCount = HazardReport::whereYear('created_at', $currentYear)->whereMonth('created_at', $m)->count();
            $iCount = InspectionReport::whereYear('created_at', $currentYear)->whereMonth('created_at', $m)->count();
            
            $monthlyTrend[] = [
                'month'      => $monthName,
                'hazard'     => $hCount,
                'inspection' => $iCount,
                'total'      => $hCount + $iCount,
            ];
        }

        // ── 6. User Stats ──────────────────────────────────────────────────
        $userStats = [
            'total'      => \App\Models\User::count(),
            'active'     => \App\Models\User::where('is_active', true)->count(),
            'superadmin' => \App\Models\User::where('role', 'superadmin')->count(),
            'admin'      => \App\Models\User::where('role', 'admin')->count(),
            'user'       => \App\Models\User::where('role', 'user')->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data'   => [
                'summary' => [
                    'total_reports'    => $hStats['total'] + $iStats['total'],
                    'total_hazard'     => $hStats['total'],
                    'total_inspection' => $iStats['total'],
                ],
                'hazard'          => $hStats,
                'inspection'      => $iStats,
                'weekly_trend'    => $weeklyTrend,
                'monthly_trend'   => $monthlyTrend,
                'latest_activities' => $latestActivities,
                'user_stats'      => $userStats,
            ]
        ]);
    }
}