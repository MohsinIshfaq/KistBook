<?php

namespace Tests\Feature\Api;

use App\Enums\AccessLevel;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\Product;
use App\Models\User;
use App\Models\UserCustomerAccess;
use App\Models\UserPlanAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SyncApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_upload_and_download_changed_records(): void
    {
        Sanctum::actingAs(User::factory()->create([
            'access_level' => AccessLevel::Owner,
            'role' => AccessLevel::Owner,
        ]));

        $uploadResponse = $this->postJson('/api/sync/upload', [
            'changes' => [
                'customers' => [
                    [
                        'local_id' => 101,
                        'card_no' => 'SYNC-1001',
                        'name' => 'Sync Customer',
                        'phone' => '03001112223',
                        'cnic' => '42101-1234567-1',
                        'address' => 'Lahore',
                        'reference' => 'Mobile app',
                        'is_deleted' => false,
                    ],
                ],
            ],
        ]);

        $uploadResponse
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.mappings.customers.0.local_id', 101);

        $serverId = $uploadResponse->json('data.mappings.customers.0.server_id');
        $this->assertNotEmpty($serverId);

        $this->assertDatabaseHas('customers', [
            'uuid' => $serverId,
            'cnic' => '42101-1234567-1',
            'is_deleted' => false,
        ]);

        $downloadResponse = $this->getJson('/api/sync/download?last_sync_date='.now()->subMinute()->toJSON());

        $downloadResponse
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.changes.customers.0.server_id', $serverId)
            ->assertJsonPath('data.changes.customers.0.name', 'Sync Customer');
    }

    public function test_owner_sync_download_only_contains_own_company_records(): void
    {
        $firstOwner = User::factory()->owner()->create();
        $secondOwner = User::factory()->owner()->create();
        $firstCustomer = Customer::factory()->create([
            'company_id' => $firstOwner->company_id,
        ]);
        Customer::factory()->create([
            'company_id' => $secondOwner->company_id,
        ]);
        Sanctum::actingAs($firstOwner);

        $response = $this->getJson('/api/sync/download');

        $response
            ->assertOk()
            ->assertJsonCount(1, 'data.changes.customers')
            ->assertJsonPath('data.changes.customers.0.server_id', $firstCustomer->uuid);
    }

    public function test_salesman_cannot_delete_user_through_sync(): void
    {
        $owner = User::factory()->owner()->create();
        $salesman = User::factory()->create([
            'company_id' => $owner->company_id,
        ]);
        Sanctum::actingAs($salesman);

        $response = $this->postJson('/api/sync/upload', [
            'changes' => [
                'users' => [
                    [
                        'server_id' => $salesman->uuid,
                        'is_deleted' => true,
                    ],
                ],
            ],
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('data.errors.users.0.message', 'Only an owner can manage company users.');
        $this->assertDatabaseHas('users', [
            'uuid' => $salesman->uuid,
            'is_deleted' => false,
        ]);
    }

    public function test_plan_access_sync_rejects_plan_already_assigned_to_another_salesman(): void
    {
        $owner = User::factory()->owner()->create();
        $firstSalesman = User::factory()->create(['company_id' => $owner->company_id]);
        $secondSalesman = User::factory()->create(['company_id' => $owner->company_id]);
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $product = Product::factory()->create(['company_id' => $owner->company_id]);
        $plan = Plan::factory()->create([
            'company_id' => $owner->company_id,
            'customer_uuid' => $customer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        UserPlanAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $firstSalesman->uuid,
            'plan_uuid' => $plan->uuid,
            'is_deleted' => false,
        ]);
        Sanctum::actingAs($owner);

        $response = $this->postJson('/api/sync/upload', [
            'changes' => [
                'user_plan_access' => [[
                    'local_id' => 99,
                    'user_uuid' => $secondSalesman->uuid,
                    'plan_uuid' => $plan->uuid,
                    'is_deleted' => false,
                ]],
            ],
        ]);

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.errors.user_plan_access.0.message',
                'This plan is already assigned to another salesman. Remove it from that user first.',
            );
        $this->assertDatabaseMissing('user_plan_access', [
            'user_uuid' => $secondSalesman->uuid,
            'plan_uuid' => $plan->uuid,
            'is_deleted' => false,
        ]);
    }

    public function test_access_plan_endpoint_rejects_plan_assigned_to_another_salesman(): void
    {
        $owner = User::factory()->owner()->create();
        $firstSalesman = User::factory()->create(['company_id' => $owner->company_id]);
        $secondSalesman = User::factory()->create(['company_id' => $owner->company_id]);
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $product = Product::factory()->create(['company_id' => $owner->company_id]);
        $plan = Plan::factory()->create([
            'company_id' => $owner->company_id,
            'customer_uuid' => $customer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        UserPlanAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $firstSalesman->uuid,
            'plan_uuid' => $plan->uuid,
            'is_deleted' => false,
        ]);
        Sanctum::actingAs($owner);

        $this->postJson('/api/access/plan', [
            'userId' => $secondSalesman->uuid,
            'planId' => $plan->uuid,
        ])
            ->assertUnprocessable()
            ->assertJsonPath(
                'errors.planId.0',
                'This plan is already assigned to another salesman. Remove it from that user first.',
            );
    }

    public function test_owner_can_replace_assignments_in_one_request(): void
    {
        $owner = User::factory()->owner()->create();
        $salesman = User::factory()->create(['company_id' => $owner->company_id]);
        $firstCustomer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $secondCustomer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $product = Product::factory()->create(['company_id' => $owner->company_id]);
        $firstPlan = Plan::factory()->create([
            'company_id' => $owner->company_id,
            'customer_uuid' => $firstCustomer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        $secondPlan = Plan::factory()->create([
            'company_id' => $owner->company_id,
            'customer_uuid' => $secondCustomer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        UserCustomerAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $salesman->uuid,
            'customer_uuid' => $secondCustomer->uuid,
            'is_deleted' => false,
        ]);
        UserPlanAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $salesman->uuid,
            'plan_uuid' => $secondPlan->uuid,
            'is_deleted' => false,
        ]);
        Sanctum::actingAs($owner);

        $this->putJson('/api/access/assignments', [
            'userId' => $salesman->uuid,
            'customerIds' => [$firstCustomer->uuid],
            'planIds' => [$firstPlan->uuid],
        ])
            ->assertOk()
            ->assertJsonPath('message', 'Assignments saved successfully.')
            ->assertJsonPath('data.userId', $salesman->uuid)
            ->assertJsonPath('data.customerAccess.0.customerId', $firstCustomer->uuid)
            ->assertJsonPath('data.planAccess.0.planId', $firstPlan->uuid)
            ->assertJsonPath('data.customerAccess.0.isDeleted', false)
            ->assertJsonPath('data.planAccess.0.isDeleted', false);

        $this->assertDatabaseHas('user_customer_access', [
            'user_uuid' => $salesman->uuid,
            'customer_uuid' => $firstCustomer->uuid,
            'is_deleted' => false,
        ]);
        $this->assertDatabaseHas('user_plan_access', [
            'user_uuid' => $salesman->uuid,
            'plan_uuid' => $firstPlan->uuid,
            'is_deleted' => false,
        ]);
        $this->assertSoftDeleted('user_customer_access', [
            'user_uuid' => $salesman->uuid,
            'customer_uuid' => $secondCustomer->uuid,
        ]);
        $this->assertSoftDeleted('user_plan_access', [
            'user_uuid' => $salesman->uuid,
            'plan_uuid' => $secondPlan->uuid,
        ]);
    }

    public function test_replace_assignments_rejects_plan_assigned_to_another_salesman(): void
    {
        $owner = User::factory()->owner()->create();
        $firstSalesman = User::factory()->create(['company_id' => $owner->company_id]);
        $secondSalesman = User::factory()->create(['company_id' => $owner->company_id]);
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $product = Product::factory()->create(['company_id' => $owner->company_id]);
        $plan = Plan::factory()->create([
            'company_id' => $owner->company_id,
            'customer_uuid' => $customer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        UserPlanAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $firstSalesman->uuid,
            'plan_uuid' => $plan->uuid,
            'is_deleted' => false,
        ]);
        Sanctum::actingAs($owner);

        $this->putJson('/api/access/assignments', [
            'userId' => $secondSalesman->uuid,
            'customerIds' => [],
            'planIds' => [$plan->uuid],
        ])
            ->assertUnprocessable()
            ->assertJsonPath(
                'errors.planIds.0',
                'This plan is already assigned to another salesman. Remove it from that user first.',
            );
    }

    public function test_salesman_cannot_replace_assignments(): void
    {
        $owner = User::factory()->owner()->create();
        $salesman = User::factory()->create(['company_id' => $owner->company_id]);
        Sanctum::actingAs($salesman);

        $this->putJson('/api/access/assignments', [
            'userId' => $salesman->uuid,
            'customerIds' => [],
            'planIds' => [],
        ])->assertForbidden();
    }

    public function test_replace_assignments_rejects_cross_company_records(): void
    {
        $owner = User::factory()->owner()->create();
        $otherOwner = User::factory()->owner()->create();
        $salesman = User::factory()->create(['company_id' => $owner->company_id]);
        $otherCustomer = Customer::factory()->create(['company_id' => $otherOwner->company_id]);
        Sanctum::actingAs($owner);

        $this->putJson('/api/access/assignments', [
            'userId' => $salesman->uuid,
            'customerIds' => [$otherCustomer->uuid],
            'planIds' => [],
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors.customerIds.0', 'One or more selected customers are unavailable.');
    }
}
