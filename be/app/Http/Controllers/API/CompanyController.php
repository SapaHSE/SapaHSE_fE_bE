<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Company;
use Illuminate\Http\Request;

class CompanyController extends Controller
{
    /**
     * GET /api/companies
     * List all companies. Supports ?active=1 to filter only active.
     */
    public function index(Request $request)
    {
        try {
            $query = Company::query()->orderBy('name');

            if ($request->filled('active')) {
                $query->where('is_active', filter_var($request->active, FILTER_VALIDATE_BOOLEAN));
            }

            if ($request->filled('category')) {
                $query->where('category', $request->category);
            }

            $companies = $query->get();

            return response()->json(['status' => 'success', 'data' => $companies]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/companies
     * Create a new company.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name'     => 'required|string|max:150|unique:companies,name',
            'code'     => 'nullable|string|max:50',
            'category' => 'required|in:owner,kontraktor,subkontraktor',
        ]);

        try {
            $company = Company::create([
                'name'     => $request->name,
                'code'     => $request->code,
                'category' => $request->category,
            ]);

            return response()->json([
                'status'  => 'success',
                'message' => 'Perusahaan berhasil ditambahkan.',
                'data'    => $company,
            ], 201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * PUT /api/companies/{id}
     * Update an existing company.
     */
    public function update(Request $request, $id)
    {
        $company = Company::findOrFail($id);

        $request->validate([
            'name'     => 'required|string|max:150|unique:companies,name,' . $id,
            'code'     => 'nullable|string|max:50',
            'category' => 'nullable|in:owner,kontraktor,subkontraktor',
        ]);

        try {
            $company->update([
                'name'     => $request->name,
                'code'     => $request->code,
                'category' => $request->category ?? $company->category,
            ]);

            return response()->json([
                'status'  => 'success',
                'message' => 'Perusahaan berhasil diperbarui.',
                'data'    => $company,
            ]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * DELETE /api/companies/{id}
     * Delete a company (and its areas via cascade).
     */
    public function destroy($id)
    {
        $company = Company::findOrFail($id);

        try {
            $company->delete();
            return response()->json(['status' => 'success', 'message' => 'Perusahaan berhasil dihapus.']);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/companies/{id}/toggle
     * Toggle company active status.
     */
    public function toggle($id)
    {
        try {
            $company = Company::findOrFail($id);
            $company->update(['is_active' => !$company->is_active]);

            return response()->json([
                'status'  => 'success',
                'message' => $company->is_active ? 'Perusahaan diaktifkan.' : 'Perusahaan dinonaktifkan.',
                'data'    => $company,
            ]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }
}