<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Area;
use App\Models\Company;
use Illuminate\Http\Request;

class AreaController extends Controller
{
    /**
     * GET /api/areas
     * List areas. Supports:
     *   ?company_id=1   → filter by company
     *   ?active=1       → filter only active areas
     */
    public function index(Request $request)
    {
        try {
            $query = Area::with('company')->orderBy('name');

            if ($request->filled('company_id')) {
                $query->forCompany((int) $request->company_id);
            }

            if ($request->filled('active')) {
                $query->where('is_active', filter_var($request->active, FILTER_VALIDATE_BOOLEAN));
            }

            $areas = $query->get()->map(fn($area) => [
                'id'           => $area->id,
                'company_id'   => $area->company_id,
                'company_name' => $area->company->name ?? null,
                'name'         => $area->name,
                'code'         => $area->code,
                'is_active'    => $area->is_active,
                'created_at'   => $area->created_at,
                'updated_at'   => $area->updated_at,
            ]);

            return response()->json(['status' => 'success', 'data' => $areas]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/areas
     * Create a new area for a company.
     */
    public function store(Request $request)
    {
        $request->validate([
            'company_id' => 'required|exists:companies,id',
            'name'       => 'required|string|max:200',
            'code'       => 'nullable|string|max:50',
        ]);

        // Check uniqueness within company
        $exists = Area::where('company_id', $request->company_id)
            ->where('name', $request->name)
            ->exists();

        if ($exists) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Area dengan nama ini sudah ada di perusahaan tersebut.',
            ], 422);
        }

        try {
            $area = Area::create([
                'company_id' => $request->company_id,
                'name'       => $request->name,
                'code'       => $request->code,
            ]);

            $area->load('company');

            return response()->json([
                'status'  => 'success',
                'message' => 'Area berhasil ditambahkan.',
                'data'    => $area,
            ], 201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * PUT /api/areas/{id}
     * Update an existing area.
     */
    public function update(Request $request, $id)
    {
        $area = Area::findOrFail($id);

        $request->validate([
            'company_id' => 'nullable|exists:companies,id',
            'name'       => 'required|string|max:200',
            'code'       => 'nullable|string|max:50',
        ]);

        $companyId = $request->company_id ?? $area->company_id;

        // Check uniqueness within company (exclude self)
        $exists = Area::where('company_id', $companyId)
            ->where('name', $request->name)
            ->where('id', '!=', $id)
            ->exists();

        if ($exists) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Area dengan nama ini sudah ada di perusahaan tersebut.',
            ], 422);
        }

        try {
            $area->update([
                'company_id' => $companyId,
                'name'       => $request->name,
                'code'       => $request->code,
            ]);

            return response()->json([
                'status'  => 'success',
                'message' => 'Area berhasil diperbarui.',
                'data'    => $area->load('company'),
            ]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * DELETE /api/areas/{id}
     * Delete an area.
     */
    public function destroy($id)
    {
        $area = Area::findOrFail($id);

        try {
            $area->delete();
            return response()->json(['status' => 'success', 'message' => 'Area berhasil dihapus.']);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/areas/{id}/toggle
     * Toggle area active status.
     */
    public function toggle($id)
    {
        try {
            $area = Area::findOrFail($id);
            $area->update(['is_active' => !$area->is_active]);

            return response()->json([
                'status'  => 'success',
                'message' => $area->is_active ? 'Area diaktifkan.' : 'Area dinonaktifkan.',
                'data'    => $area,
            ]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }
}