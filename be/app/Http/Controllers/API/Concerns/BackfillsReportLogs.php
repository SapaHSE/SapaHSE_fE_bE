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
     * Sub-statuses that are allowed to be skipped over (auto-backfilled to
     * the log) when the user jumps to a later stage. Stages NOT listed here
     * are mandatory checkpoints that must be reached explicitly.
     */
    private const SKIPPABLE_SUB_STATUSES = [
        'preparing',
    ];

    /**
     * Highest LINEAR_FLOW index already reached by the report's logs.
     * Returns -1 if the report has no log with a linear sub-status yet.
     */
    protected function currentLinearIndex(Model $report): int
    {
        $existingSubStatuses = $report->logs()
            ->orderBy('created_at')
            ->pluck('sub_status')
            ->filter()
            ->all();

        $lastReachedIndex = -1;
        foreach ($existingSubStatuses as $sub) {
            $idx = array_search($sub, self::LINEAR_FLOW, true);
            if ($idx !== false && $idx > $lastReachedIndex) {
                $lastReachedIndex = $idx;
            }
        }
        return $lastReachedIndex;
    }

    /**
     * Validate that the requested status/sub_status transition is a legal
     * step on the linear timeline. Returns null if allowed, or an error
     * message if it should be rejected.
     *
     * Rules:
     *  - closed reports cannot be modified.
     *  - rejected/deferred sub-statuses are valid terminal exits at any stage.
     *  - moving backwards in LINEAR_FLOW is rejected.
     *  - going back to 'pending' once the report has progressed is rejected.
     *  - forward skipping is allowed only when EVERY skipped intermediate
     *    sub-status is listed in SKIPPABLE_SUB_STATUSES (currently only
     *    'preparing'), except for the admin-only validating -> assigned
     *    transition which may skip 'approved'. The skipped stages are
     *    auto-logged via backfillSkippedSubStatusLogs. Any other mandatory
     *    checkpoint ('executing', 'reviewing', etc.) must be reached
     *    explicitly.
     *
     * Caller is responsible for bypassing this check for superadmin.
     */
    protected function assertLinearProgression(
        Model $report,
        ?string $newStatus,
        ?string $newSubStatus,
        bool $allowAssignedFromValidating = false
    ): ?string {
        // Closed reports are final.
        if ($report->status === 'closed') {
            return 'Laporan sudah ditutup. Status tidak dapat diubah.';
        }

        // Terminal exit is always allowed (when not yet closed).
        if ($newStatus === 'rejected'
            || $newSubStatus === 'rejected'
            || $newSubStatus === 'deferred') {
            return null;
        }

        // Block regression to pre-open state.
        if ($newStatus === 'pending'
            && in_array($report->status, ['open', 'in_progress', 'closed'], true)) {
            return 'Status tidak bisa dimundurkan ke pending. Timeline harus linear.';
        }

        if ($newSubStatus === null) {
            return null;
        }

        $targetIndex = array_search($newSubStatus, self::LINEAR_FLOW, true);
        if ($targetIndex === false) {
            // Unknown sub-status - let validation upstream handle it.
            return null;
        }

        $lastReachedIndex = $this->currentLinearIndex($report);
        $validatingIndex = array_search('validating', self::LINEAR_FLOW, true);
        $assignedIndex = array_search('assigned', self::LINEAR_FLOW, true);

        if ($targetIndex < $lastReachedIndex) {
            return 'Status tidak bisa dimundurkan. Timeline harus linear.';
        }

        // Forward skip: every intermediate stage must be skippable.
        for ($i = $lastReachedIndex + 1; $i < $targetIndex; $i++) {
            $stage = self::LINEAR_FLOW[$i];
            if (
                $allowAssignedFromValidating
                && $lastReachedIndex === $validatingIndex
                && $targetIndex === $assignedIndex
                && $stage === 'approved'
            ) {
                continue;
            }
            if (!in_array($stage, self::SKIPPABLE_SUB_STATUSES, true)) {
                return 'Status harus melalui tahap ' . ucfirst($stage)
                    . ' terlebih dahulu.';
            }
        }

        return null;
    }

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

        $lastReachedIndex = $this->currentLinearIndex($report);

        if ($targetIndex - $lastReachedIndex <= 1) {
            // Nothing skipped (or moving backwards) -> no backfill.
            return;
        }

        $existingSubStatuses = $report->logs()
            ->orderBy('created_at')
            ->pluck('sub_status')
            ->filter()
            ->all();
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
