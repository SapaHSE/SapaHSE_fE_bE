<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\ReadStatus;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class ReportController extends Controller
{
    // GET /api/reports
    // Filter  : ?type=hazard|inspection &severity=low|medium|high &status=open|in_progress|closed
    // Search  : ?search=keyword
    // Sort    : ?sort=oldest
    // Paginate: ?page=1&per_page=10
    public function index(Request $request)
    {
        $query  = Report::with('user')->latest();
        $userId = Auth::id();

        if ($request->filled('type'))       $query->where('type', $request->type);
        if ($request->filled('severity'))   $query->where('severity', $request->severity);
        if ($request->filled('status'))     $query->where('status', $request->status);
        if ($request->filled('department')) $query->where('reported_department', $request->department);

        if ($request->filled('search')) {
            $kw = $request->search;
            $query->where(function ($q) use ($kw) {
                $q->where('title', 'like', "%{$kw}%")
                  ->orWhere('description', 'like', "%{$kw}%")
                  ->orWhere('location', 'like', "%{$kw}%")
                  ->orWhere('name_pja', 'like', "%{$kw}%");
            });
        }

        if ($request->sort === 'oldest') $query->oldest();

        $perPage = (int) $request->get('per_page', 10);
        $reports = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'meta'   => [
                'total'        => $reports->total(),
                'per_page'     => $reports->perPage(),
                'current_page' => $reports->currentPage(),
                'last_page'    => $reports->lastPage(),
                'has_more'     => $reports->hasMorePages(),
            ],
            'data' => collect($reports->items())->map(fn($r) => $this->formatReport($r, $userId)),
        ]);
    }

    // POST /api/reports
    public function store(Request $request)
    {
        $request->validate([
            'title'               => 'required|string|max:200',
            'description'         => 'required|string',
            'type'                => 'required|in:hazard,inspection',
            'severity'            => 'required|in:low,medium,high',
            'location'            => 'required|string|max:200',
            'name_pja'            => 'nullable|string|max:100',
            'reported_department' => 'nullable|string|max:100',
            'image'               => 'nullable|image|mimes:jpg,jpeg,png|max:2048',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $imageUrl = asset('storage/' . $request->file('image')->store('reports', 'public'));
        }

        $report = Report::create([
            'user_id'             => Auth::id(),
            'title'               => $request->title,
            'description'         => $request->description,
            'type'                => $request->type,
            'severity'            => $request->severity,
            'status'              => 'open',
            'location'            => $request->location,
            'name_pja'            => $request->name_pja,
            'reported_department' => $request->reported_department,
            'image_url'           => $imageUrl,
        ]);

        $report->load('user');

        return response()->json([
            'status'  => 'success',
            'message' => 'Report submitted successfully',
            'data'    => $this->formatReport($report, Auth::id()),
        ], 201);
    }

    // GET /api/reports/{id} — auto mark as read
    public function show($id)
    {
        $report = Report::with('user')->findOrFail($id);
        $userId = Auth::id();

        ReadStatus::firstOrCreate([
            'user_id'   => $userId,
            'item_id'   => $report->id,
            'item_type' => 'report',
        ], ['read_at' => now()]);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatReport($report, $userId),
        ]);
    }

    // PATCH /api/reports/{id}/status
    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:open,in_progress,closed',
        ]);

        $report = Report::findOrFail($id);
        $report->update(['status' => $request->status]);

        return response()->json([
            'status'  => 'success',
            'message' => 'Report status updated successfully',
            'data'    => $this->formatReport($report->load('user'), Auth::id()),
        ]);
    }

    // DELETE /api/reports/{id}
    public function destroy($id)
    {
        $report = Report::findOrFail($id);
        $user   = Auth::user();

        if ($report->user_id !== $user->id && $user->role !== 'admin') {
            return response()->json([
                'status'  => 'error',
                'message' => 'You do not have permission to delete this report',
            ], 403);
        }

        if ($report->image_url) {
            $path = str_replace(asset('storage/') . '/', '', $report->image_url);
            Storage::disk('public')->delete($path);
        }

        $report->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Report deleted successfully',
        ]);
    }

    private function formatReport(Report $report, string $userId): array
    {
        return [
            'id'                  => $report->id,
            'title'               => $report->title,
            'description'         => $report->description,
            'type'                => $report->type,
            'severity'            => $report->severity,
            'status'              => $report->status,
            'location'            => $report->location,
            'name_pja'            => $report->name_pja,
            'reported_department' => $report->reported_department,
            'image_url'           => $report->image_url,
            'is_read'             => $report->isReadBy($userId),
            'reported_by'         => $report->user ? [
                'id'          => $report->user->id,
                'full_name'   => $report->user->full_name,
                'employee_id' => $report->user->employee_id,
                'position'    => $report->user->position,
                'department'  => $report->user->department,
            ] : null,
            'created_at'          => $report->created_at?->toDateTimeString(),
            'updated_at'          => $report->updated_at?->toDateTimeString(),
        ];
    }
}