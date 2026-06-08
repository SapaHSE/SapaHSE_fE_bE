<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\User;
use Illuminate\Http\Request;

class DepartmentController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $departments = Department::orderBy('name', 'asc')->get();
        return response()->json([
            'status' => 'success',
            'message' => 'Daftar department berhasil diambil',
            'data'    => $departments
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:100|unique:departments,name',
            'is_hrd' => 'sometimes|boolean',
        ]);

        $department = Department::create([
            'name' => trim($request->name),
            'is_hrd' => $request->boolean('is_hrd', false),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Department berhasil ditambahkan',
            'data'    => $department
        ], 201);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, $id)
    {
        $department = Department::find($id);

        if (!$department) {
            return response()->json([
            'status' => 'error',
                'message' => 'Department tidak ditemukan'
            ], 404);
        }

        $request->validate([
            'name' => 'required|string|max:100|unique:departments,name,' . $id,
            'is_hrd' => 'sometimes|boolean',
        ]);

        $oldName = $department->name;
        $newName = trim($request->name);
        $requestedIsHrd = $request->has('is_hrd')
            ? $request->boolean('is_hrd')
            : (bool) $department->is_hrd;

        if ($department->is_hrd && ! $requestedIsHrd && Department::where('is_hrd', true)->count() <= 1) {
            return response()->json([
                'status' => 'error',
                'message' => 'Department HRD terakhir tidak dapat dinonaktifkan karena dibutuhkan untuk approval registrasi.'
            ], 422);
        }

        $department->name = $newName;
        if ($request->has('is_hrd')) {
            $department->is_hrd = $requestedIsHrd;
        }
        $department->save();

        if ($oldName !== $newName) {
            User::where('department', $oldName)->update(['department' => $newName]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Department berhasil diupdate',
            'data'    => $department
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy($id)
    {
        $department = Department::find($id);

        if (!$department) {
            return response()->json([
            'status' => 'error',
                'message' => 'Department tidak ditemukan'
            ], 404);
        }

        $usedByUsers = User::where('department', $department->name)->exists();
        if ($usedByUsers) {
            return response()->json([
                'status' => 'error',
                'message' => 'Department masih digunakan oleh user dan tidak dapat dihapus.'
            ], 422);
        }

        if ($department->is_hrd && Department::where('is_hrd', true)->count() <= 1) {
            return response()->json([
                'status' => 'error',
                'message' => 'Department HRD terakhir tidak dapat dihapus karena dibutuhkan untuk approval registrasi.'
            ], 422);
        }

        $department->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Department berhasil dihapus'
        ]);
    }
}
