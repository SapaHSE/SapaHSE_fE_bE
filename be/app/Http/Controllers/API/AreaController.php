<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Area;
use App\Models\Company;
use App\Models\User;
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

            $areas = $query->get()->map(fn($area) => $this->formatArea($area));

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
            'company_id'   => 'required|exists:companies,id',
            'name'         => 'required|string|max:200',
            'code'         => 'nullable|string|max:50',
            'pic_user_id'  => 'nullable|exists:users,id',
            'pic_user_ids' => 'nullable|array',
            'pic_user_ids.*' => 'integer|exists:users,id',
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
            $picUserIds = $this->normalizePicUserIds($request, null);
            $area = Area::create([
                'company_id'  => $request->company_id,
                'name'        => $request->name,
                'code'        => $request->code,
                'pic_user_id' => $picUserIds[0] ?? $request->pic_user_id,
                'pic_user_ids' => $picUserIds,
            ]);

            return response()->json([
                'status'  => 'success',
                'message' => 'Area berhasil ditambahkan.',
                'data'    => $this->formatArea($area->load('company')),
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
            'company_id'   => 'nullable|exists:companies,id',
            'name'         => 'required|string|max:200',
            'code'         => 'nullable|string|max:50',
            'pic_user_id'  => 'nullable|exists:users,id',
            'pic_user_ids' => 'nullable|array',
            'pic_user_ids.*' => 'integer|exists:users,id',
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
            $picUserIds = $this->normalizePicUserIds($request, $area->pic_user_ids ?? [$area->pic_user_id]);

            $area->update([
                'company_id'  => $companyId,
                'name'        => $request->name,
                'code'        => $request->code,
                'pic_user_id' => $picUserIds[0] ?? null,
                'pic_user_ids' => $picUserIds,
            ]);

            return response()->json([
                'status'  => 'success',
                'message' => 'Area berhasil diperbarui.',
                'data'    => $this->formatArea($area->load('company')),
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
                'data'    => $this->formatArea($area->load('company')),
            ]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    private function formatArea(Area $area): array
    {
        $picIds = array_values(array_filter(array_map(
            fn($id) => (int) $id,
            $area->pic_user_ids ?? ($area->pic_user_id ? [$area->pic_user_id] : [])
        ), fn($id) => $id > 0));

        return [
            'id'             => $area->id,
            'company_id'     => $area->company_id,
            'company_name'   => $area->company?->name,
            'pic_user_id'    => $picIds[0] ?? null,
            'pic_user_ids'   => $picIds,
            'pic_user_name'  => $this->resolvePicUserNames($picIds),
            'pic_users'      => $this->resolvePicUsers($picIds),
            'name'           => $area->name,
            'code'           => $area->code,
            'is_active'      => $area->is_active,
            'created_at'     => $area->created_at,
            'updated_at'     => $area->updated_at,
        ];
    }

    private function normalizePicUserIds(Request $request, ?array $fallback): array
    {
        if ($request->has('pic_user_ids')) {
            $raw = $request->input('pic_user_ids', []);
            $ids = is_array($raw) ? $raw : [];
        } elseif ($request->filled('pic_user_id')) {
            $ids = [$request->input('pic_user_id')];
        } else {
            $ids = $fallback ?? [];
        }

        $ids = array_values(array_unique(array_filter(array_map(
            fn($id) => (int) $id,
            $ids
        ), fn($id) => $id > 0)));

        return $ids;
    }

    /**
     * @return array<int, array{id:int, full_name:string, employee_id:?string, department:?string, position:?string, jabatan:?string}>
     */
    private function resolvePicUsers(?array $ids): array
    {
        $ids = array_values(array_filter(array_map(
            fn($id) => (int) $id,
            $ids ?? []
        ), fn($id) => $id > 0));

        if (empty($ids)) {
            return [];
        }

        return User::whereIn('id', $ids)
            ->where('is_active', true)
            ->orderBy('full_name')
            ->get()
            ->map(fn(User $user) => [
                'id' => $user->id,
                'full_name' => $user->full_name,
                'employee_id' => $user->employee_id,
                'department' => $user->department,
                'position' => $user->position,
                'jabatan' => $user->jabatan,
            ])
            ->values()
            ->all();
    }

    private function resolvePicUserNames(?array $ids): string
    {
        $users = $this->resolvePicUsers($ids);
        return implode(', ', array_map(
            fn(array $user) => trim(($user['full_name'] ?? '') . (($user['employee_id'] ?? '') ? ' - ' . $user['employee_id'] : '')),
            $users
        ));
    }
}
