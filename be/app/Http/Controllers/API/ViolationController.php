<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserViolation;
use Illuminate\Http\Request;

class ViolationController extends Controller
{
    public function index(Request $request)
    {
        UserViolation::where('status', 'Aktif')
            ->whereNotNull('expired_at')
            ->where('expired_at', '<', now()->toDateString())
            ->update(['status' => 'Selesai']);

        $search = $request->query('search');
        $status = $request->query('status');
        $type = $request->query('type');
        $perPage = $request->query('per_page', 10);

        $query = UserViolation::with('user:id,full_name,employee_id,profile_photo')
            ->orderBy('date_of_violation', 'desc');

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                    ->orWhere('location', 'like', "%{$search}%")
                    ->orWhere('violation_category', 'like', "%{$search}%")
                    ->orWhere('violation_subcategory', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search) {
                        $uq->where('full_name', 'like', "%{$search}%")
                            ->orWhere('employee_id', 'like', "%{$search}%");
                    });
            });
        }

        if ($status && $status !== 'Semua') {
            $query->where('status', $status);
        }

        if ($type && $type !== 'Semua') {
            $query->where('type', $type);
        }

        $violations = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'message' => 'Violations retrieved successfully',
            'data' => $violations,
        ]);
    }

    public function store(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        $data = $this->validatedData($request);
        if (empty($data['date_of_violation'])) {
            $data['date_of_violation'] = now()->toDateString();
        }

        $violation = $user->violations()->create($data);

        return response()->json([
            'status' => 'success',
            'message' => 'Violation recorded successfully.',
            'data' => $violation->load('user:id,full_name,employee_id,profile_photo'),
        ], 201);
    }

    public function show(string $violationId)
    {
        $violation = UserViolation::with('user:id,full_name,employee_id,profile_photo')
            ->findOrFail($violationId);

        return response()->json([
            'status' => 'success',
            'data' => $violation,
        ]);
    }

    public function update(Request $request, string $violationId)
    {
        $violation = UserViolation::findOrFail($violationId);
        $violation->update($this->validatedData($request));

        return response()->json([
            'status' => 'success',
            'message' => 'Violation updated successfully.',
            'data' => $violation->load('user:id,full_name,employee_id,profile_photo'),
        ]);
    }

    public function destroy(string $violationId)
    {
        $violation = UserViolation::findOrFail($violationId);
        $violation->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Violation deleted successfully.',
        ]);
    }

    private function validatedData(Request $request): array
    {
        return $request->validate([
            'title' => 'required|string|max:150',
            'violation_category' => 'nullable|string|max:100',
            'violation_subcategory' => 'nullable|string|max:100',
            'type' => 'nullable|in:Violation,Incident',
            'level' => 'nullable|integer|min:1|max:3',
            'description' => 'nullable|string',
            'location' => 'nullable|string|max:150',
            'date_of_violation' => 'nullable|date',
            'expired_at' => 'nullable|date',
            'status' => 'nullable|string|max:50',
            'sanction' => 'nullable|string|max:200',
            'file_url' => 'nullable|string|max:255',
        ]);
    }
}
