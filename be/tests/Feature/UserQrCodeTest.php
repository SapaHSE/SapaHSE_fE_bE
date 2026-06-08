<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserQrCodeTest extends TestCase
{
    use RefreshDatabase;

    public function test_qr_is_created_after_hrd_and_admin_approval_then_email_verification(): void
    {
        Department::create([
            'name' => 'HRD',
            'is_hrd' => true,
        ]);

        $hrd = User::factory()->create([
            'department' => 'HRD',
        ]);

        $admin = User::factory()->create([
            'role' => 'admin',
        ]);

        $user = User::factory()->unverified()->create([
            'is_active' => false,
            'registration_status' => 'pending_hrd',
            'email_verification_token' => 'verify-token',
            'qr_code' => null,
        ]);

        Sanctum::actingAs($hrd);

        $this->putJson('/api/admin/registration-approvals/' . $user->id . '/approve')
            ->assertOk();

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'is_active' => false,
            'registration_status' => 'pending_admin',
        ]);

        Sanctum::actingAs($admin);

        $this->putJson('/api/admin/registration-approvals/' . $user->id . '/approve')
            ->assertOk();

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'is_active' => true,
            'registration_status' => 'approved',
            'qr_code' => null,
        ]);

        $this->get('/api/email/verify/' . $user->id . '/verify-token')
            ->assertOk();

        $user->refresh();
        $this->assertNotNull($user->qr_code);
        $this->assertStringStartsWith('SAPA-HSE-USER-', $user->qr_code);

        $initialCode = $user->qr_code;

        $this->postJson('/api/login', [
            'login' => $user->personal_email,
            'password' => 'password',
        ])
            ->assertOk()
            ->assertJsonPath('data.qr_code', $initialCode);

        $this->assertSame($initialCode, $user->fresh()->qr_code);
    }

    public function test_scan_qr_returns_active_verified_user_profile(): void
    {
        $scanner = User::factory()->create();
        $target = User::factory()->create([
            'qr_code' => null,
        ]);
        $target->ensureQrCode();

        Sanctum::actingAs($scanner);

        $this->getJson('/api/qr/scan?qr_code=' . urlencode($target->qr_code))
            ->assertOk()
            ->assertJsonPath('type', 'user')
            ->assertJsonPath('data.id', $target->id)
            ->assertJsonPath('data.qr_code', $target->qr_code)
            ->assertJsonPath('data.full_name', $target->full_name);
    }
}
