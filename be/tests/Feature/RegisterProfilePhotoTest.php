<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class RegisterProfilePhotoTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_without_profile_photo_url_stores_null_profile_photo(): void
    {
        $payload = $this->validPayload();

        $this->postJson('/api/register', $payload)
            ->assertCreated()
            ->assertJsonPath('data.personal_email', $payload['personal_email']);

        $this->assertDatabaseHas('users', [
            'employee_id' => $payload['employee_id'],
            'personal_email' => $payload['personal_email'],
            'profile_photo' => null,
            'is_active' => false,
            'qr_code' => null,
        ]);
    }

    public function test_register_with_profile_photo_url_stores_the_avatar_url(): void
    {
        $photoUrl = 'https://gwzlqpukshwgmphsynkv.supabase.co/storage/v1/object/public/images/avatars/register-avatar.jpg';
        $payload = $this->validPayload([
            'profile_photo_url' => $photoUrl,
        ]);

        $this->postJson('/api/register', $payload)
            ->assertCreated()
            ->assertJsonPath('data.personal_email', $payload['personal_email']);

        $this->assertDatabaseHas('users', [
            'employee_id' => $payload['employee_id'],
            'profile_photo' => $photoUrl,
        ]);
    }

    public function test_register_rejects_an_invalid_profile_photo_url(): void
    {
        $payload = $this->validPayload([
            'profile_photo_url' => 'not-a-valid-url',
        ]);

        $this->postJson('/api/register', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors(['profile_photo_url']);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function validPayload(array $overrides = []): array
    {
        $suffix = Str::lower(Str::random(10));

        return array_merge([
            'employee_id' => 'REG-' . $suffix,
            'full_name' => 'Register Tester',
            'personal_email' => 'register-' . $suffix . '@gmail.com',
            'work_email' => 'register-' . $suffix . '@outlook.com',
            'password' => 'secret123',
            'phone_number' => '+628123456789',
            'position' => 'Safety Officer',
            'jabatan' => 'Staff',
            'department' => 'HSE',
            'company' => 'PT Bukit Baiduri Energi',
            'tipe_afiliasi' => 'Owner',
        ], $overrides);
    }
}
