<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Department;
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
            'name' => 'required|string|max:100|unique:departments,name'
        ]);

        $department = Department::create([
            'name' => trim($request->name)
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
            'name' => 'required|string|max:100|unique:departments,name,' . $id
        ]);

        $department->update([
            'name' => trim($request->name)
        ]);

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

        $department->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Department berhasil dihapus'
        ]);
    }
}