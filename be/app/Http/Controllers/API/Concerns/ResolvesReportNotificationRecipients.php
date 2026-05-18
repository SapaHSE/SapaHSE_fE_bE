<?php

namespace App\Http\Controllers\API\Concerns;

use App\Models\ReportLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;

trait ResolvesReportNotificationRecipients
{
    /**
     * Build the report-update notification audience from all persisted report stakeholders.
     */
    private function resolveReportNotificationRecipients(
        Model $report,
        string $reportableType,
        ?string $taggedUserId,
        ?string $currentUserId,
        array $nameFields,
        array $departmentFields
    ): Collection {
        $explicitUserIds = collect([$report->getAttribute('user_id'), $taggedUserId])
            ->merge(
                ReportLog::query()
                    ->where('reportable_type', $reportableType)
                    ->where('reportable_id', $report->getKey())
                    ->whereNotNull('tagged_user_id')
                    ->pluck('tagged_user_id')
            )
            ->filter()
            ->unique()
            ->values();

        $nameValues = $this->collectStakeholderFieldValues($report, $nameFields);
        $departmentValues = $this->collectStakeholderFieldValues($report, $departmentFields);
        $hasFieldValues = $nameValues->isNotEmpty() || $departmentValues->isNotEmpty();

        $users = User::query()
            ->where('is_active', true)
            ->where(function ($query) use ($explicitUserIds, $hasFieldValues) {
                if ($explicitUserIds->isNotEmpty()) {
                    $query->whereIn('id', $explicitUserIds);
                }

                if ($hasFieldValues) {
                    $query->orWhereNotNull('full_name')
                        ->orWhereNotNull('department');
                }
            })
            ->get();

        return $users
            ->filter(function (User $user) use ($explicitUserIds, $nameValues, $departmentValues, $currentUserId) {
                if ($currentUserId !== null && $user->id === $currentUserId) {
                    return false;
                }

                if ($explicitUserIds->contains($user->id)) {
                    return true;
                }

                foreach ($nameValues as $fieldValue) {
                    if ($this->stakeholderFieldMatches($fieldValue, $user->full_name)) {
                        return true;
                    }
                }

                foreach ($departmentValues as $fieldValue) {
                    if ($this->stakeholderFieldMatches($fieldValue, $user->department)) {
                        return true;
                    }
                }

                return false;
            })
            ->unique('id')
            ->values();
    }

    private function collectStakeholderFieldValues(Model $report, array $fields): Collection
    {
        return collect($fields)
            ->map(fn(string $field) => $report->getAttribute($field))
            ->filter(fn($value) => is_string($value) && trim($value) !== '')
            ->values();
    }

    private function stakeholderFieldMatches(?string $fieldValue, ?string $needle): bool
    {
        $needle = strtolower(trim((string) $needle));
        $fieldValue = strtolower(trim((string) $fieldValue));

        if ($needle === '' || $fieldValue === '') {
            return false;
        }

        foreach (preg_split('/[,;]+/', $fieldValue) ?: [] as $token) {
            if (trim((string) $token) === $needle) {
                return true;
            }
        }

        return str_contains($fieldValue, $needle);
    }
}
