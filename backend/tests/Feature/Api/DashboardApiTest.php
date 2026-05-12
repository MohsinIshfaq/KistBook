<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DashboardApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_requires_authentication_and_returns_json_401(): void
    {
        $this->getJson('/api/dashboard')
            ->assertUnauthorized()
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_authenticated_user_can_view_dashboard(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/dashboard')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'total_customers',
                    'total_products',
                    'total_plans',
                    'pending_amount',
                    'collected_amount',
                    'overdue_amount',
                    'paid_installments',
                    'pending_installments',
                    'overdue_installments',
                ],
            ]);
    }
}
