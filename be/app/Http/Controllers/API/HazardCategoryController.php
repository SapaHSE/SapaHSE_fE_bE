<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\HazardCategory;
use App\Models\HazardSubcategory;
use Illuminate\Http\Request;

class HazardCategoryController extends Controller
{
    // ── Categories ────────────────────────────────────────────────────────────

    /**
     * GET /api/hazard-categories
     * List all categories with their APPROVED subcategories.
     */
    public function index()
    {
        try {
            $categories = HazardCategory::with('subcategories')->get();
            return response()->json(['status' => 'success', 'data' => $categories]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/hazard-categories
     * Create a new category.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255|unique:hazard_categories,name',
            'code' => 'nullable|string|max:50',
        ]);

        try {
            $category = HazardCategory::create([
                'name' => $request->name,
                'code' => $request->code,
            ]);
            return response()->json(['status' => 'success', 'data' => $category->load('subcategories')], 201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * PUT /api/hazard-categories/{id}
     * Update an existing category.
     */
    public function update(Request $request, $id)
    {
        $category = HazardCategory::findOrFail($id);

        $request->validate([
            'name' => 'required|string|max:255|unique:hazard_categories,name,' . $id,
            'code' => 'nullable|string|max:50',
        ]);

        try {
            $category->update([
                'name' => $request->name,
                'code' => $request->code,
            ]);
            return response()->json(['status' => 'success', 'data' => $category->load('subcategories')]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * DELETE /api/hazard-categories/{id}
     * Delete a category and its subcategories.
     */
    public function destroy($id)
    {
        $category = HazardCategory::findOrFail($id);
        try {
            $category->delete(); // subcategories deleted via cascade
            return response()->json(['status' => 'success', 'message' => 'Category deleted.']);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    // ── Subcategories ─────────────────────────────────────────────────────────



    public function storeSubcategory(Request $request, $categoryId)
    {
        HazardCategory::findOrFail($categoryId);

        $request->validate([
            'name' => 'required|string|max:255',
            'abbreviation' => 'nullable|string|max:50',
            'description' => 'nullable|string',
        ]);

        try {
            $sub = HazardSubcategory::create([
                'category_id' => $categoryId,
                'name'        => $request->name,
                'abbreviation'=> $request->abbreviation,
                'description' => $request->description,
            ]);

            return response()->json([
                'status' => 'success', 
                'message' => 'Subkategori berhasil dibuat.',
                'data' => $sub
            ], 201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }



    /**
     * PUT /api/hazard-categories/{categoryId}/subcategories/{subId}
     * Update a subcategory.
     */
    public function updateSubcategory(Request $request, $categoryId, $subId)
    {
        $sub = HazardSubcategory::where('category_id', $categoryId)->findOrFail($subId);

        $request->validate([
            'name' => 'required|string|max:255',
            'abbreviation' => 'nullable|string|max:50',
            'description' => 'nullable|string',
            'is_active' => 'nullable|boolean',
        ]);

        try {
            $sub->update($request->only(['name', 'abbreviation', 'description', 'is_active']));
            return response()->json(['status' => 'success', 'data' => $sub]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/hazard-categories/subcategories/{subId}/toggle
     * Toggle subcategory active status.
     */
    public function toggleSubcategory($subId)
    {
        try {
            $sub = HazardSubcategory::findOrFail($subId);
            $sub->update(['is_active' => !$sub->is_active]);
            return response()->json(['status' => 'success', 'data' => $sub]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * DELETE /api/hazard-categories/{categoryId}/subcategories/{subId}
     * Delete a subcategory.
     */
    public function destroySubcategory($categoryId, $subId)
    {
        $sub = HazardSubcategory::where('category_id', $categoryId)->findOrFail($subId);
        try {
            $sub->delete();
            return response()->json(['status' => 'success', 'message' => 'Subcategory deleted.']);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }
}