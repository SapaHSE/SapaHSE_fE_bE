<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\ViolationCategory;
use App\Models\ViolationSubcategory;
use Illuminate\Http\Request;

class ViolationCategoryController extends Controller
{
    public function index()
    {
        try {
            $categories = ViolationCategory::with('subcategories')->get();
            return response()->json(['status' => 'success', 'data' => $categories]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255|unique:violation_categories,name',
            'code' => 'nullable|string|max:50',
        ]);

        try {
            $category = ViolationCategory::create([
                'name' => $request->name,
                'code' => $request->code,
            ]);
            return response()->json(['status' => 'success', 'data' => $category->load('subcategories')], 201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function update(Request $request, $id)
    {
        $category = ViolationCategory::findOrFail($id);

        $request->validate([
            'name' => 'required|string|max:255|unique:violation_categories,name,' . $id,
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

    public function destroy($id)
    {
        $category = ViolationCategory::findOrFail($id);

        try {
            $category->delete();
            return response()->json(['status' => 'success', 'message' => 'Category deleted.']);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function storeSubcategory(Request $request, $categoryId)
    {
        ViolationCategory::findOrFail($categoryId);

        $request->validate([
            'name' => 'required|string|max:255',
            'abbreviation' => 'nullable|string|max:50',
            'description' => 'nullable|string',
        ]);

        try {
            $sub = ViolationSubcategory::create([
                'category_id' => $categoryId,
                'name' => $request->name,
                'abbreviation' => $request->abbreviation,
                'description' => $request->description,
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Subkategori berhasil dibuat.',
                'data' => $sub,
            ], 201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function updateSubcategory(Request $request, $categoryId, $subId)
    {
        $sub = ViolationSubcategory::where('category_id', $categoryId)->findOrFail($subId);

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

    public function toggleSubcategory($subId)
    {
        try {
            $sub = ViolationSubcategory::findOrFail($subId);
            $sub->update(['is_active' => !$sub->is_active]);
            return response()->json(['status' => 'success', 'data' => $sub]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function destroySubcategory($categoryId, $subId)
    {
        $sub = ViolationSubcategory::where('category_id', $categoryId)->findOrFail($subId);

        try {
            $sub->delete();
            return response()->json(['status' => 'success', 'message' => 'Subcategory deleted.']);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }
}
