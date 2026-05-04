<?php

namespace App\Services;

use App\Models\HazardReport;

/**
 * Validates hazard report status transitions
 * Implements state machine to prevent invalid status hops
 */
class ReportStatusValidator
{
    /**
     * Valid status transitions from current state
     * Defines allowed next states/sub-states from each current state
     */
    private static array $validTransitions = [
        // OPEN status transitions
        'open' => [
            'validating' => [
                // Admin validates - can move to approved or reject
                'approved' => ['admin_only' => true],
                'rejected' => ['admin_only' => true],
                // Cannot jump to other statuses from validating
            ],
            'approved' => [
                // Admin has approved - can move to assigned
                'assigned' => ['admin_only' => true],
                // Cannot move to in_progress directly from approved
            ],
            'assigned' => [
                // Can move to in_progress to start work
                'in_progress' => [
                    'preparing' => true, // Must start with preparing
                ],
                // Cannot jump to other statuses
            ],
        ],

        // IN_PROGRESS status transitions
        'in_progress' => [
            'preparing' => [
                // Setup phase - move to executing
                'in_progress' => ['executing' => true],
                // Cannot jump to reviewing directly
            ],
            'executing' => [
                // Work in progress - move to reviewing
                'in_progress' => ['reviewing' => true],
                // Can also move back to preparing if needed
                'in_progress' => ['preparing' => true],
            ],
            'reviewing' => [
                // Verification phase - can close
                'closed' => ['resolved' => ['admin_only' => true]],
                // Or defer if needed
                'closed' => ['deferred' => ['admin_only' => true]],
                // Or move back to executing if more work needed
                'in_progress' => ['executing' => true],
            ],
        ],

        // CLOSED status transitions (terminal)
        'closed' => [
            'resolved' => [
                // Cannot transition out of resolved
            ],
            'rejected' => [
                // Cannot transition out of rejected
            ],
            'deferred' => [
                // Can reopen deferred reports
                'in_progress' => ['preparing' => true],
            ],
        ],
    ];

    /**
     * Validates if the requested transition is allowed
     *
     * @param HazardReport $report Current report state
     * @param string $newStatus Requested new status
     * @param string|null $newSubStatus Requested new sub-status
     * @param bool $isAdmin Is the requesting user an admin
     * @return array ['valid' => bool, 'error' => string|null]
     */
    public static function validateTransition(
        HazardReport $report,
        string $newStatus,
        ?string $newSubStatus,
        bool $isAdmin
    ): array {
        $currentStatus = $report->status;
        $currentSubStatus = $report->sub_status;

        // Special case: reject request becomes closed/rejected
        if ($newStatus === 'rejected') {
            $newStatus = 'closed';
            $newSubStatus = 'rejected';
        }

        // Check if transition exists in valid transitions
        if (!isset(self::$validTransitions[$currentStatus][$currentSubStatus])) {
            return [
                'valid' => false,
                'error' => "Current status '{$currentStatus}/{$currentSubStatus}' tidak dapat diupdate."
            ];
        }

        $allowedTransitions = self::$validTransitions[$currentStatus][$currentSubStatus];

        // Check if new status is allowed from current state
        if (!isset($allowedTransitions[$newStatus])) {
            return [
                'valid' => false,
                'error' => "Tidak dapat mengubah status dari '{$currentStatus}' ke '{$newStatus}'. "
                    . "Harap ikuti urutan tahapan yang tepat."
            ];
        }

        $statusRules = $allowedTransitions[$newStatus];

        // Handle nested sub-status rules
        if (is_array($statusRules) && !isset($statusRules['admin_only'])) {
            // For in_progress transitions
            if ($newStatus === 'in_progress') {
                if (!isset($statusRules[$newSubStatus])) {
                    return [
                        'valid' => false,
                        'error' => "Sub-status '{$newSubStatus}' tidak valid untuk status '{$newStatus}' "
                            . "dari state '{$currentStatus}/{$currentSubStatus}'."
                    ];
                }
                $subRules = $statusRules[$newSubStatus];
                if (is_array($subRules) && isset($subRules['admin_only']) && $subRules['admin_only'] && !$isAdmin) {
                    return [
                        'valid' => false,
                        'error' => "Hanya Admin yang dapat melakukan transisi ini."
                    ];
                }
            } elseif ($newStatus === 'closed') {
                // For closed transitions (resolved/rejected/deferred)
                if (!isset($statusRules[$newSubStatus])) {
                    return [
                        'valid' => false,
                        'error' => "Sub-status '{$newSubStatus}' tidak valid untuk menutup laporan."
                    ];
                }
                $subRules = $statusRules[$newSubStatus];
                if (is_array($subRules) && isset($subRules['admin_only']) && $subRules['admin_only'] && !$isAdmin) {
                    return [
                        'valid' => false,
                        'error' => "Hanya Admin yang dapat menutup laporan."
                    ];
                }
            }
        }

        // Check for admin-only transitions
        if (is_array($statusRules) && isset($statusRules['admin_only']) && $statusRules['admin_only'] && !$isAdmin) {
            return [
                'valid' => false,
                'error' => "Hanya Admin yang dapat melakukan transisi ini."
            ];
        }

        return ['valid' => true, 'error' => null];
    }

    /**
     * Get allowed next statuses/sub-statuses from current state
     * Used by frontend to show valid options
     *
     * @param HazardReport $report
     * @param bool $isAdmin
     * @return array ['status' => ['sub_statuses' => []]]
     */
    public static function getAllowedTransitions(
        HazardReport $report,
        bool $isAdmin
    ): array {
        $currentStatus = $report->status;
        $currentSubStatus = $report->sub_status;

        if (!isset(self::$validTransitions[$currentStatus][$currentSubStatus])) {
            return [];
        }

        $allowed = [];
        $transitions = self::$validTransitions[$currentStatus][$currentSubStatus];

        foreach ($transitions as $nextStatus => $rules) {
            // Skip admin-only transitions if not admin
            if (is_array($rules) && isset($rules['admin_only']) && $rules['admin_only'] && !$isAdmin) {
                continue;
            }

            $subStatuses = [];

            if (is_array($rules) && !isset($rules['admin_only'])) {
                foreach ($rules as $subStatus => $subRules) {
                    // Skip admin-only sub-statuses if not admin
                    if (is_array($subRules) && isset($subRules['admin_only']) && $subRules['admin_only'] && !$isAdmin) {
                        continue;
                    }
                    $subStatuses[] = $subStatus;
                }
            }

            if (!empty($subStatuses) || $rules === true) {
                $allowed[$nextStatus] = empty($subStatuses) ? [] : $subStatuses;
            }
        }

        return $allowed;
    }

    /**
     * Get human-readable next step suggestion
     *
     * @param HazardReport $report
     * @return string|null
     */
    public static function getNextStepSuggestion(HazardReport $report): ?string
    {
        $status = $report->status;
        $subStatus = $report->sub_status;

        $suggestions = [
            'open/validating' => "Menunggu validasi admin. Admin akan memeriksa kelayakan laporan.",
            'open/approved' => "Laporan disetujui. Admin akan menugaskan ke departemen terkait.",
            'open/assigned' => "Laporan ditugaskan. Klik 'Update Status' untuk memulai pekerjaan (In Progress → Preparing).",
            'in_progress/preparing' => "Fase persiapan. Setelah siap, ubah status ke Executing.",
            'in_progress/executing' => "Pekerjaan sedang berjalan. Setelah selesai, ubah ke Reviewing dengan bukti foto.",
            'in_progress/reviewing' => "Verifikasi sedang dilakukan. Setelah terbukti efektif, admin akan menutup sebagai Resolved.",
            'closed/resolved' => "Laporan ditutup. Hazard telah dieliminasi.",
            'closed/rejected' => "Laporan ditolak. Hazard dianggap tidak valid atau sudah teratasi.",
            'closed/deferred' => "Laporan ditunda. Akan dilanjutkan pada tanggal yang ditentukan.",
        ];

        $key = "{$status}/{$subStatus}";
        return $suggestions[$key] ?? null;
    }
}
