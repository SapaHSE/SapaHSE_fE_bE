<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class CompanyController extends Controller
{
    /**
     * GET /api/companies
     * List all companies. Supports ?active=1 to filter only active.
     */
    public function index(Request $request)
    {
        try {
            $query = Company::with('kttUser')->orderBy('name');

            if ($request->filled('active')) {
                $query->where('is_active', filter_var($request->active, FILTER_VALIDATE_BOOLEAN));
            }

            if ($request->filled('category')) {
                $query->where('category', $this->normalizeCategory($request->category));
            }

            $companies = $query->get()->map(fn(Company $company) => $company->toApiArray());

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
            'name'             => 'required|string|max:150|unique:companies,name',
            'code'             => 'nullable|string|max:50',
            'logo_url'         => 'nullable|url|max:2048',
            'ktt_user_id'      => 'nullable|exists:users,id',
            'emergency_number' => 'nullable|string|max:50',
            'ert_freq'         => 'nullable|string|max:100',
            'category'         => 'required|in:owner,kontraktor,contractor,subkontraktor,sub contractor',
        ]);

        try {
            $category = $this->normalizeCategory($request->category);
            $kttUserId = $this->nullableValue($request->input('ktt_user_id'));
            $this->ensureKttMatchesCompany($kttUserId, $request->name, $category);

            $company = Company::create([
                'name'             => $request->name,
                'code'             => $this->nullableValue($request->input('code')),
                'logo_url'         => $this->nullableValue($request->input('logo_url')),
                'ktt_user_id'      => $kttUserId,
                'emergency_number' => $this->nullableValue($request->input('emergency_number')),
                'ert_freq'         => $this->nullableValue($request->input('ert_freq')),
                'category'         => $category,
            ]);

            return response()->json([
                'status'  => 'success',
                'message' => 'Perusahaan berhasil ditambahkan.',
                'data'    => $company->toApiArray(),
            ], 201);
        } catch (ValidationException $e) {
            throw $e;
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
            'name'             => 'required|string|max:150|unique:companies,name,' . $id,
            'code'             => 'nullable|string|max:50',
            'logo_url'         => 'nullable|url|max:2048',
            'ktt_user_id'      => 'nullable|exists:users,id',
            'emergency_number' => 'nullable|string|max:50',
            'ert_freq'         => 'nullable|string|max:100',
            'category'         => 'nullable|in:owner,kontraktor,contractor,subkontraktor,sub contractor',
        ]);

        try {
            $category = $this->normalizeCategory($request->input('category') ?? $company->category);
            $kttUserId = $request->has('ktt_user_id')
                ? $this->nullableValue($request->input('ktt_user_id'))
                : $company->ktt_user_id;
            $this->ensureKttMatchesCompany($kttUserId, $request->name, $category);

            $payload = [
                'name'     => $request->name,
                'code'     => $this->nullableValue($request->input('code')),
                'category' => $category,
            ];

            foreach (['logo_url', 'ktt_user_id', 'emergency_number', 'ert_freq'] as $field) {
                if ($request->has($field)) {
                    $payload[$field] = $this->nullableValue($request->input($field));
                }
            }

            $company->update($payload);

            return response()->json([
                'status'  => 'success',
                'message' => 'Perusahaan berhasil diperbarui.',
                'data'    => $company->fresh('kttUser')->toApiArray(),
            ]);
        } catch (ValidationException $e) {
            throw $e;
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
                'data'    => $company->fresh('kttUser')->toApiArray(),
            ]);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    private function normalizeCategory(string $category): string
    {
        return match ($category) {
            'contractor' => 'kontraktor',
            'sub contractor' => 'subkontraktor',
            default => $category,
        };
    }

    private function nullableValue(mixed $value): ?string
    {
        $trimmed = trim((string) ($value ?? ''));
        return $trimmed === '' ? null : $trimmed;
    }

    private function ensureKttMatchesCompany(?string $userId, string $companyName, string $category): void
    {
        if ($userId === null) {
            return;
        }

        $user = User::find($userId);
        if (! $user || ! $user->is_active) {
            throw ValidationException::withMessages([
                'ktt_user_id' => 'Kepala Teknik Tambang harus user aktif.',
            ]);
        }

        $userCompany = match ($category) {
            'kontraktor' => $user->perusahaan_kontraktor,
            'subkontraktor' => $user->sub_kontraktor,
            default => $user->company,
        };

        if (User::normalizeCompanyLookup((string) $userCompany) !== User::normalizeCompanyLookup($companyName)) {
            throw ValidationException::withMessages([
                'ktt_user_id' => 'Kepala Teknik Tambang harus berasal dari perusahaan yang dipilih.',
            ]);
        }
    }
}
