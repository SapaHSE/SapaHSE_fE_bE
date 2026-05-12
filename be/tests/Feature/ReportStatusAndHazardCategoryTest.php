<?php

namespace Tests\Feature;

use App\Models\HazardCategory;
use App\Models\HazardReport;
use App\Models\InspectionReport;
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
}

