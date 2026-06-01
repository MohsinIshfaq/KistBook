<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_register_login_with_email_and_view_company_profile(): void
    {
        $registerResponse = $this->postJson('/api/auth/register', $this->ownerPayload());

        $registerResponse
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Account created successfully.')
            ->assertJsonPath('user.role', 'owner')
            ->assertJsonPath('user.email', 'tester@example.com')
            ->assertJsonPath('company.name', 'KistBook Test Company');

        $companyId = $registerResponse->json('company.id');
        $ownerId = $registerResponse->json('user.id');
        $this->assertDatabaseHas('companies', [
            'id' => $companyId,
            'owner_id' => $ownerId,
        ]);

        $loginResponse = $this->postJson('/api/auth/login', [
            'login' => 'tester@example.com',
            'password' => 'password',
        ]);
        $token = $loginResponse->json('token');

        $loginResponse
            ->assertOk()
            ->assertJsonPath('user.companyId', $companyId)
            ->assertJsonPath('company.id', $companyId);

        $this->postJson('/api/auth/login', [
            'login' => '03001234567',
            'password' => 'password',
        ])->assertOk();

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/auth/profile')
            ->assertOk()
            ->assertJsonPath('user.phoneNumber', '03001234567')
            ->assertJsonPath('company.id', $companyId)
            ->assertJsonPath('user.role', 'owner')
            ->assertJsonMissingPath('role');

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/auth/logout')
            ->assertOk()
            ->assertJsonPath('message', 'Logout successful.');

        $this->app['auth']->forgetGuards();

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/auth/profile')
            ->assertUnauthorized();
    }

    public function test_registration_rejects_duplicate_owner_email_or_phone(): void
    {
        $this->postJson('/api/auth/register', $this->ownerPayload())->assertCreated();

        $this->postJson('/api/auth/register', $this->ownerPayload())
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'phoneNumber'])
            ->assertJsonMissingPath('errors.phone');
    }

    public function test_owner_can_create_salesman_but_salesman_cannot_create_users(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        $response = $this->postJson('/api/company/users', [
            'name' => 'Sales Man',
            'email' => 'salesman@example.com',
            'phone' => '03123456789',
            'password' => 'password',
            'password_confirmation' => 'password',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('user.role', 'salesman')
            ->assertJsonPath('user.companyId', $owner->company_id);

        $salesman = User::query()->where('email', 'salesman@example.com')->firstOrFail();
        Sanctum::actingAs($salesman);

        $this->postJson('/api/company/users', [
            'name' => 'Another Salesman',
            'email' => 'another@example.com',
            'phone' => '03123456780',
            'password' => 'password',
            'password_confirmation' => 'password',
        ])->assertForbidden();
    }

    private function ownerPayload(): array
    {
        return [
            'name' => 'Test Owner',
            'email' => 'tester@example.com',
            'phone' => '03001234567',
            'password' => 'password',
            'password_confirmation' => 'password',
            'company_name' => 'KistBook Test Company',
            'company_phone' => '03001234567',
            'company_address' => 'Bahawalpur',
        ];
    }
}
