<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CustomerApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_fetch_customer_detail(): void
    {
        $owner = User::factory()->owner()->create();
        $customer = Customer::factory()->create([
            'company_id' => $owner->company_id,
            'name' => 'Ali Khan',
        ]);
        Sanctum::actingAs($owner);

        $this->getJson('/api/customers/'.$customer->uuid)
            ->assertOk()
            ->assertJsonPath('data.customerName', 'Ali Khan');
    }

    public function test_direct_customer_mutation_and_list_routes_are_not_exposed(): void
    {
        $owner = User::factory()->owner()->create();
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);
        Sanctum::actingAs($owner);

        $this->getJson('/api/customers')->assertNotFound();
        $this->postJson('/api/customers', [])->assertNotFound();
        $this->patchJson('/api/customers/'.$customer->uuid, [])->assertStatus(405);
        $this->deleteJson('/api/customers/'.$customer->uuid)->assertStatus(405);
    }

    public function test_user_cannot_fetch_another_company_customer(): void
    {
        $firstOwner = User::factory()->owner()->create();
        $secondOwner = User::factory()->owner()->create();
        $customer = Customer::factory()->create([
            'company_id' => $firstOwner->company_id,
        ]);
        Sanctum::actingAs($secondOwner);

        $this->getJson('/api/customers/'.$customer->uuid)->assertNotFound();
    }
}
