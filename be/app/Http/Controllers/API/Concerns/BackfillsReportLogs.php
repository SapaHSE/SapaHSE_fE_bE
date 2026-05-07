<?php

namespace App\Http\Controllers\API\Concerns;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

/**
 * Inserts log rows for any sub-statuses that the user skipped over when
 * jumping straight to a later stage (e.g. assigned -> reviewing must also
 * record preparing and executing). The acting user (Auth::id()) is the
 * actor on every backfilled row so audits reflect who moved the report
 * through each stage.
 */
trait BackfillsReportLogs
{
    /** Linear progression for non-terminal sub-statuses. */
    private const LINEAR_FLOW = [
        'validating',
        'approved',
        'assigned',
        'preparing',
        'executing',
        'reviewing',
        'resolved',
    ];

    /** Maps each linear sub-status to its parent main status. */
    private const SUB_STATUS_PARENT = [
        'validating'  => 'open',
        'approved'    => 'open',
        'assigned'    => 'open',
        'preparing'   => 'in_progress',
        'executing'   => 'in_progress',
        'reviewing'   => 'in_progress',
        'resolved'    => 'closed',
    ];

    /**
     * Create log rows for every sub-status strictly between the report's
     * last-reached linear sub-status and the new target.
     */
    protected function backfillSkippedSubStatusLogs(
        Model $report,
        ?string $newSubStatus,
        ?string $taggedUserId
    ): void {
        if ($newSubStatus === null) {
            return;
        }

        $targetIndex = array_search($newSubStatus, self::LINEAR_FLOW, true);
        if ($targetIndex === false) {
            // Terminal (rejected, deferred) or unknown sub-status -> no backfill.
            return;
        }

        $existingSubStatuses = $report->logs()
            ->orderBy('created_at')
            ->pluck('sub_status')
            ->filter()
            ->all();

        // Last linear sub-status the report has already recorded.
        $lastReachedIndex = -1;
        foreach ($existingSubStatuses as $sub) {
            $idx = array_search($sub, self::LINEAR_FLOW, true);
            if ($idx !== false && $idx > $lastReachedIndex) {
                $lastReachedIndex = $idx;
            }
        }

        if ($targetIndex - $lastReachedIndex <= 1) {
            // Nothing skipped (or moving backwards) -> no backfill.
            return;
        }

        $alreadyLogged = array_flip($existingSubStatuses);

        for ($i = $lastReachedIndex + 1; $i < $targetIndex; $i++) {
            $sub = self::LINEAR_FLOW[$i];
            if (isset($alreadyLogged[$sub])) {
                continue; // Idempotency: don't duplicate existing rows.
            }

            $report->logs()->create([
                'user_id'        => Auth::id(),
                'tagged_user_id' => $taggedUserId,
                'status'         => self::SUB_STATUS_PARENT[$sub],
                'sub_status'     => $sub,
                'message'        => 'Tahap ' . ucfirst($sub) . ' dilakukan.',
                'image_url'      => null,
                'image_urls'     => null,
            ]);
        }
    }
}
