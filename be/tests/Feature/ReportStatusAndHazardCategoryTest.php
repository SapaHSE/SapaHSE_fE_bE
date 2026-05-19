<?php

namespace Tests\Feature;

use App\Models\HazardCategory;
use App\Models\HazardReport;
use App\Models\InspectionReport;
use App\Models\Notification;
use App\Models\ReportLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportStatusAndHazardCategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_hazard_and_inspection_start_with_open_and_validating(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
        ]);
        Sanctum::actingAs($admin);

        HazardCategory::create([
            'code' => 'KTA',
            'name' => 'KTA (Kondisi Tidak Aman)',
        ]);
        HazardCategory::create([
            'code' => 'TTA',
            'name' => 'TTA (Tindakan Tidak Aman)',
        ]);

        $hazardResponse = $this->postJson('/api/hazard-reports', [
            'title' => 'Unsafe scaffolding',
            'description' => 'Scaffolding guardrail is missing.',
            'location' => 'Area A',
            'severity' => 'high',
            'hazard_category' => ' kta , TTA , KTA ',
            'isPublic' => true,
        ]);

        $hazardResponse
            ->assertCreated()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.sub_status', 'validating')
            ->assertJsonPath('data.hazard_category_codes.0', 'KTA')
            ->assertJsonPath('data.hazard_category_codes.1', 'TTA')
            ->assertJsonPath('data.hazard_category_names.0', 'KTA (Kondisi Tidak Aman)')
            ->assertJsonPath('data.hazard_category_names.1', 'TTA (Tindakan Tidak Aman)');

        $hazardId = (string) $hazardResponse->json('data.id');

        $this->assertDatabaseHas('hazard_reports', [
            'id' => $hazardId,
            'status' => 'open',
            'sub_status' => 'validating',
            'hazard_category' => 'KTA,TTA',
        ]);

        $this->assertDatabaseHas('report_logs', [
            'reportable_id' => $hazardId,
            'reportable_type' => HazardReport::class,
            'status' => 'open',
            'sub_status' => 'validating',
        ]);

        $inspectionResponse = $this->postJson('/api/inspection-reports', [
            'title' => 'Daily inspection',
            'description' => 'Initial inspection report.',
            'location' => 'Area B',
        ]);

        $inspectionResponse
            ->assertCreated()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.sub_status', 'validating');

        $inspectionId = (string) $inspectionResponse->json('data.id');

        $this->assertDatabaseHas('inspection_reports', [
            'id' => $inspectionId,
            'status' => 'open',
            'sub_status' => 'validating',
        ]);

        $this->assertDatabaseHas('report_logs', [
            'reportable_id' => $inspectionId,
            'reportable_type' => InspectionReport::class,
            'status' => 'open',
            'sub_status' => 'validating',
        ]);
    }

    public function test_hazard_show_and_inbox_include_category_codes_and_names(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
        ]);
        Sanctum::actingAs($admin);

        HazardCategory::create([
            'code' => 'KTA',
            'name' => 'KTA (Kondisi Tidak Aman)',
        ]);
        HazardCategory::create([
            'code' => 'TTA',
            'name' => 'TTA (Tindakan Tidak Aman)',
        ]);

        $report = HazardReport::create([
            'user_id' => $admin->id,
            'title' => 'Leaking valve',
            'description' => 'Valve leak detected.',
            'status' => 'open',
            'sub_status' => 'validating',
            'location' => 'Plant 1',
            'severity' => 'medium',
            'hazard_category' => 'TTA,KTA',
            'is_public' => true,
            'pic_department' => $admin->full_name,
        ]);

        ReportLog::create([
            'reportable_id' => $report->id,
            'reportable_type' => HazardReport::class,
            'user_id' => $admin->id,
            'status' => 'open',
            'sub_status' => 'validating',
            'message' => 'Created',
        ]);

        $this->getJson('/api/hazard-reports/' . $report->id)
            ->assertOk()
            ->assertJsonPath('data.hazard_category_codes.0', 'TTA')
            ->assertJsonPath('data.hazard_category_codes.1', 'KTA')
            ->assertJsonPath('data.hazard_category_names.0', 'TTA (Tindakan Tidak Aman)')
            ->assertJsonPath('data.hazard_category_names.1', 'KTA (Kondisi Tidak Aman)');

        $inboxResponse = $this->getJson('/api/inbox?type=personal')
            ->assertOk();

        $items = collect($inboxResponse->json('data'));
        $hazardItem = $items->firstWhere('id', $report->id);

        $this->assertNotNull($hazardItem);
        $this->assertSame(['TTA', 'KTA'], $hazardItem['hazard_category_codes'] ?? []);
        $this->assertSame(
            ['TTA (Tindakan Tidak Aman)', 'KTA (Kondisi Tidak Aman)'],
            $hazardItem['hazard_category_names'] ?? []
        );
    }

    public function test_hazard_status_update_notifies_all_stakeholders_except_actor_once(): void
    {
        $actor = User::factory()->create([
            'role' => 'admin',
            'full_name' => 'Admin User',
            'department' => 'Admin',
        ]);
        $reporter = User::factory()->create([
            'full_name' => 'Reporter User',
            'department' => 'Reporter',
        ]);
        $historicalTagged = User::factory()->create([
            'full_name' => 'Historical Tagged',
            'department' => 'Tagged',
        ]);
        $newTagged = User::factory()->create([
            'full_name' => 'New Tagged',
            'department' => 'New',
        ]);
        $picUser = User::factory()->create([
            'full_name' => 'PJA Person',
            'department' => 'PJA',
        ]);
        $departmentUser = User::factory()->create([
            'full_name' => 'Department Person',
            'department' => 'HSE',
        ]);

        $report = HazardReport::create([
            'user_id' => $reporter->id,
            'title' => 'Unsafe work platform',
            'description' => 'Missing guardrail.',
            'status' => 'open',
            'sub_status' => 'validating',
            'location' => 'Area A',
            'severity' => 'high',
            'pic_department' => $actor->full_name . ', ' . $historicalTagged->full_name . ', ' . $picUser->full_name,
            'reported_department' => 'HSE',
            'is_public' => true,
        ]);

        ReportLog::create([
            'reportable_id' => $report->id,
            'reportable_type' => HazardReport::class,
            'user_id' => $reporter->id,
            'tagged_user_id' => $historicalTagged->id,
            'status' => 'open',
            'sub_status' => 'validating',
            'message' => 'Initial tag',
        ]);

        Sanctum::actingAs($actor);

        $this->postJson('/api/hazard-reports/' . $report->id . '/status', [
            'status' => 'in_progress',
            'sub_status' => 'assigned',
            'message' => 'Assigned for follow-up',
            'tagged_user_id' => $newTagged->id,
        ])->assertOk();

        $recipientIds = Notification::where('type', 'hazard_update')
            ->pluck('user_id')
            ->all();

        $this->assertEqualsCanonicalizing([
            $reporter->id,
            $historicalTagged->id,
            $newTagged->id,
            $picUser->id,
            $departmentUser->id,
        ], $recipientIds);
        $this->assertDatabaseMissing('notifications', [
            'type' => 'hazard_update',
            'user_id' => $actor->id,
        ]);
        $this->assertSame(1, Notification::where('type', 'hazard_update')
            ->where('user_id', $historicalTagged->id)
            ->count());
    }

    public function test_hazard_suspect_cannot_update_even_when_tagged_admin_or_superadmin(): void
    {
        foreach (['user', 'admin', 'superadmin'] as $role) {
            $actor = User::factory()->create([
                'role' => $role,
                'full_name' => 'Suspect ' . $role,
                'department' => 'Operations',
            ]);
            $report = $this->createHazardWithInitialLog([
                'status' => 'open',
                'sub_status' => 'approved',
                'pic_department' => $actor->full_name,
                'reported_department' => 'Operations',
                'pelaku_pelanggaran' => $actor->full_name,
            ]);

            Sanctum::actingAs($actor);

            $this->postJson('/api/hazard-reports/' . $report->id . '/status', [
                'status' => 'open',
                'sub_status' => 'assigned',
                'message' => 'Attempted update as suspect',
            ])->assertForbidden();

            $this->assertDatabaseHas('hazard_reports', [
                'id' => $report->id,
                'status' => 'open',
                'sub_status' => 'approved',
            ]);
        }
    }

    public function test_hazard_admin_policy_does_not_require_tagging(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
            'full_name' => 'Global Hazard Admin',
            'department' => 'Admin',
        ]);
        $report = $this->createHazardWithInitialLog([
            'status' => 'open',
            'sub_status' => 'validating',
            'pic_department' => 'Other PJA',
            'reported_department' => 'Operations',
        ]);

        Sanctum::actingAs($admin);

        $this->postJson('/api/hazard-reports/' . $report->id . '/status', [
            'status' => 'in_progress',
            'sub_status' => 'assigned',
            'message' => 'Assigned by global admin',
        ])->assertOk();

        $this->assertDatabaseHas('hazard_reports', [
            'id' => $report->id,
            'status' => 'in_progress',
            'sub_status' => 'assigned',
        ]);
    }

    public function test_hazard_admin_still_cannot_move_backward_or_update_closed_report(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
            'full_name' => 'Linear Hazard Admin',
        ]);
        Sanctum::actingAs($admin);

        $approvedReport = $this->createHazardWithInitialLog([
            'status' => 'open',
            'sub_status' => 'approved',
        ]);

        $this->postJson('/api/hazard-reports/' . $approvedReport->id . '/status', [
            'status' => 'open',
            'sub_status' => 'validating',
            'message' => 'Move backward',
        ])->assertUnprocessable();

        $this->assertDatabaseHas('hazard_reports', [
            'id' => $approvedReport->id,
            'status' => 'open',
            'sub_status' => 'approved',
        ]);

        $closedReport = $this->createHazardWithInitialLog([
            'status' => 'closed',
            'sub_status' => 'resolved',
        ]);

        $this->postJson('/api/hazard-reports/' . $closedReport->id . '/status', [
            'status' => 'in_progress',
            'sub_status' => 'reviewing',
            'message' => 'Reopen closed report',
        ])->assertUnprocessable();

        $this->assertDatabaseHas('hazard_reports', [
            'id' => $closedReport->id,
            'status' => 'closed',
            'sub_status' => 'resolved',
        ]);
    }

    public function test_hazard_pja_non_admin_restrictions_still_apply(): void
    {
        $pja = User::factory()->create([
            'role' => 'user',
            'full_name' => 'PJA Non Admin',
            'department' => 'Operations',
        ]);
        Sanctum::actingAs($pja);

        $validatingReport = $this->createHazardWithInitialLog([
            'status' => 'open',
            'sub_status' => 'validating',
            'pic_department' => $pja->full_name,
            'reported_department' => 'Operations',
        ]);

        $this->postJson('/api/hazard-reports/' . $validatingReport->id . '/status', [
            'status' => 'open',
            'sub_status' => 'approved',
            'message' => 'Approve as PJA',
        ])->assertForbidden();

        $approvedReport = $this->createHazardWithInitialLog([
            'status' => 'open',
            'sub_status' => 'approved',
            'pic_department' => $pja->full_name,
            'reported_department' => 'Operations',
        ]);

        $this->postJson('/api/hazard-reports/' . $approvedReport->id . '/status', [
            'status' => 'open',
            'sub_status' => 'assigned',
            'message' => 'Assign as PJA',
        ])->assertOk();

        $this->assertDatabaseHas('hazard_reports', [
            'id' => $approvedReport->id,
            'status' => 'open',
            'sub_status' => 'assigned',
        ]);
    }

    public function test_inspection_status_update_notifies_all_stakeholders_except_actor_once(): void
    {
        $actor = User::factory()->create([
            'role' => 'superadmin',
            'full_name' => 'Inspection Admin',
            'department' => 'Admin',
        ]);
        $reporter = User::factory()->create([
            'full_name' => 'Inspection Reporter',
            'department' => 'Reporter',
        ]);
        $historicalTagged = User::factory()->create([
            'full_name' => 'Inspection Historical Tagged',
            'department' => 'Tagged',
        ]);
        $newTagged = User::factory()->create([
            'full_name' => 'Inspection New Tagged',
            'department' => 'New',
        ]);
        $inspectorUser = User::factory()->create([
            'full_name' => 'Field Inspector',
            'department' => 'Inspector',
        ]);
        $departmentUser = User::factory()->create([
            'full_name' => 'Maintenance Person',
            'department' => 'Maintenance',
        ]);

        $report = InspectionReport::create([
            'user_id' => $reporter->id,
            'title' => 'Daily inspection',
            'description' => 'Inspection follow-up required.',
            'status' => 'open',
            'sub_status' => 'validating',
            'location' => 'Workshop',
            'name_inspector' => $actor->full_name . ', ' . $inspectorUser->full_name,
            'reported_department' => 'Maintenance',
        ]);

        ReportLog::create([
            'reportable_id' => $report->id,
            'reportable_type' => InspectionReport::class,
            'user_id' => $reporter->id,
            'tagged_user_id' => $historicalTagged->id,
            'status' => 'open',
            'sub_status' => 'validating',
            'message' => 'Initial tag',
        ]);

        Sanctum::actingAs($actor);

        $this->postJson('/api/inspection-reports/' . $report->id . '/status', [
            'status' => 'in_progress',
            'sub_status' => 'assigned',
            'message' => 'Assigned for inspection',
            'tagged_user_id' => $newTagged->id,
        ])->assertOk();

        $recipientIds = Notification::where('type', 'inspection_update')
            ->pluck('user_id')
            ->all();

        $this->assertEqualsCanonicalizing([
            $reporter->id,
            $historicalTagged->id,
            $newTagged->id,
            $inspectorUser->id,
            $departmentUser->id,
        ], $recipientIds);
        $this->assertDatabaseMissing('notifications', [
            'type' => 'inspection_update',
            'user_id' => $actor->id,
        ]);
        $this->assertSame(1, Notification::where('type', 'inspection_update')
            ->where('user_id', $historicalTagged->id)
            ->count());
    }

    private function createHazardWithInitialLog(array $attributes = []): HazardReport
    {
        $reporter = User::factory()->create([
            'full_name' => 'Hazard Reporter ' . uniqid(),
            'department' => 'Reporter',
        ]);

        $report = HazardReport::create(array_merge([
            'user_id' => $reporter->id,
            'title' => 'Policy test hazard',
            'description' => 'Policy test hazard description.',
            'status' => 'open',
            'sub_status' => 'validating',
            'location' => 'Policy Area',
            'severity' => 'medium',
            'is_public' => true,
        ], $attributes));

        ReportLog::create([
            'reportable_id' => $report->id,
            'reportable_type' => HazardReport::class,
            'user_id' => $reporter->id,
            'status' => $report->status,
            'sub_status' => $report->sub_status,
            'message' => 'Initial status',
        ]);

        return $report;
    }
}
