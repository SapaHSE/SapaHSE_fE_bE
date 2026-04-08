<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\ChecklistItem;
use App\Models\Inspection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class InspectionController extends Controller
{
    // GET /api/inspections
    public function index(Request $request)
    {
        $query = Inspection::with(['user', 'checklistItems'])->latest();

        if ($request->filled('result')) $query->where('result', $request->result);
        if ($request->filled('area'))   $query->where('area', 'like', "%{$request->area}%");

        if ($request->filled('search')) {
            $kw = $request->search;
            $query->where(function ($q) use ($kw) {
                $q->where('title', 'like', "%{$kw}%")
                  ->orWhere('location', 'like', "%{$kw}%")
                  ->orWhere('inspector_name', 'like', "%{$kw}%");
            });
        }

        $perPage     = (int) $request->get('per_page', 10);
        $inspections = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'meta'   => [
                'total'        => $inspections->total(),
                'per_page'     => $inspections->perPage(),
                'current_page' => $inspections->currentPage(),
                'last_page'    => $inspections->lastPage(),
                'has_more'     => $inspections->hasMorePages(),
            ],
            'data' => collect($inspections->items())->map(fn($i) => $this->formatInspection($i)),
        ]);
    }

    // POST /api/inspections
    public function store(Request $request)
    {
        $request->validate([
            'title'                      => 'required|string|max:200',
            'area'                       => 'required|string|max:100',
            'location'                   => 'required|string|max:200',
            'inspector_name'             => 'required|string|max:100',
            'result'                     => 'required|in:compliant,non_compliant,needs_follow_up',
            'notes'                      => 'nullable|string',
            'image'                      => 'nullable|image|mimes:jpg,jpeg,png|max:2048',
            'checklist'                  => 'nullable|array',
            'checklist.*.label'          => 'required|string|max:200',
            'checklist.*.is_checked'     => 'boolean',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $imageUrl = asset('storage/' . $request->file('image')->store('inspections', 'public'));
        }

        $inspection = Inspection::create([
            'user_id'        => Auth::id(),
            'title'          => $request->title,
            'area'           => $request->area,
            'location'       => $request->location,
            'inspector_name' => $request->inspector_name,
            'result'         => $request->result,
            'notes'          => $request->notes,
            'image_url'      => $imageUrl,
        ]);

        if ($request->filled('checklist')) {
            foreach ($request->checklist as $i => $item) {
                ChecklistItem::create([
                    'inspection_id' => $inspection->id,
                    'label'         => $item['label'],
                    'is_checked'    => $item['is_checked'] ?? false,
                    'sort_order'    => $i,
                ]);
            }
        }

        $inspection->load(['user', 'checklistItems']);

        return response()->json([
            'status'  => 'success',
            'message' => 'Inspection report submitted successfully',
            'data'    => $this->formatInspection($inspection),
        ], 201);
    }

    // GET /api/inspections/{id}
    public function show($id)
    {
        $inspection = Inspection::with(['user', 'checklistItems'])->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatInspection($inspection),
        ]);
    }

    // DELETE /api/inspections/{id}
    public function destroy($id)
    {
        $inspection = Inspection::findOrFail($id);
        $user       = Auth::user();

        if ($inspection->user_id !== $user->id && $user->role !== 'admin') {
            return response()->json([
                'status'  => 'error',
                'message' => 'You do not have permission to delete this inspection',
            ], 403);
        }

        if ($inspection->image_url) {
            $path = str_replace(asset('storage/') . '/', '', $inspection->image_url);
            Storage::disk('public')->delete($path);
        }

        $inspection->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'Inspection deleted successfully',
        ]);
    }

    private function formatInspection(Inspection $inspection): array
    {
        return [
            'id'             => $inspection->id,
            'title'          => $inspection->title,
            'area'           => $inspection->area,
            'location'       => $inspection->location,
            'inspector_name' => $inspection->inspector_name,
            'result'         => $inspection->result,
            'notes'          => $inspection->notes,
            'image_url'      => $inspection->image_url,
            'checklist'      => $inspection->checklistItems->map(fn($c) => [
                'id'         => $c->id,
                'label'      => $c->label,
                'is_checked' => $c->is_checked,
                'sort_order' => $c->sort_order,
            ]),
            'reported_by'    => $inspection->user ? [
                'id'          => $inspection->user->id,
                'full_name'   => $inspection->user->full_name,
                'employee_id' => $inspection->user->employee_id,
                'position'    => $inspection->user->position,
            ] : null,
            'created_at'     => $inspection->created_at?->toDateTimeString(),
        ];
    }
}
