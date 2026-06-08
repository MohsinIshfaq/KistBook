<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\Product;
use App\Models\User;
use App\Models\UserCustomerAccess;
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

    public function test_owner_can_fetch_customer_plan_details_with_products_first(): void
    {
        [$owner, $customer, $product] = $this->recordsForPlanDetail();
        $planUuid = $this->createInstallmentPlan($customer, $product);

        $this->getJson('/api/customers/'.$customer->uuid.'/plans')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Customer plan details fetched successfully.')
            ->assertJsonPath('data.customerId', $customer->uuid)
            ->assertJsonPath('data.products.0.serverId', $product->uuid)
            ->assertJsonPath('data.products.0.productName', $product->product_name)
            ->assertJsonPath('data.plans.0.serverId', $planUuid)
            ->assertJsonPath('data.plans.0.customerId', $customer->uuid)
            ->assertJsonStructure([
                'serverTime',
                'data' => [
                    'products' => [['serverId', 'productName']],
                    'plans' => [['serverId', 'selectedProducts', 'schedules']],
                ],
            ]);

        $this->assertSame($owner->company_id, $customer->company_id);
    }

    public function test_salesman_can_fetch_assigned_customer_plan_details(): void
    {
        [$owner, $customer, $product] = $this->recordsForPlanDetail();
        $this->createInstallmentPlan($customer, $product);
        $salesman = User::factory()->create(['company_id' => $owner->company_id]);
        UserCustomerAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $salesman->uuid,
            'customer_uuid' => $customer->uuid,
            'is_deleted' => false,
        ]);
        Sanctum::actingAs($salesman);

        $this->getJson('/api/customers/'.$customer->uuid.'/plans')
            ->assertOk()
            ->assertJsonCount(1, 'data.products')
            ->assertJsonCount(1, 'data.plans');
    }

    public function test_user_cannot_fetch_another_company_customer_plan_details(): void
    {
        $firstOwner = User::factory()->owner()->create();
        $secondOwner = User::factory()->owner()->create();
        $customer = Customer::factory()->create([
            'company_id' => $firstOwner->company_id,
        ]);
        Sanctum::actingAs($secondOwner);

        $this->getJson('/api/customers/'.$customer->uuid.'/plans')
            ->assertNotFound();
    }

    private function recordsForPlanDetail(): array
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        return [
            $owner,
            Customer::factory()->create(['company_id' => $owner->company_id]),
            Product::factory()->create([
                'company_id' => $owner->company_id,
                'product_name' => 'Detail Product',
                'base_price' => 1000,
                'sales_price' => 1000,
            ]),
        ];
    }

    private function createInstallmentPlan(Customer $customer, Product $product): string
    {
        return $this->postJson('/api/installment-plans', [
            'customerId' => $customer->uuid,
            'mode' => 'common',
            'selectedProducts' => [[
                'productId' => $product->uuid,
                'quantity' => 1,
                'agreedPrice' => 1000,
            ]],
            'commonDeposit' => 100,
            'commonInstallmentAmount' => 300,
            'commonFrequencyInDays' => 30,
            'commonFirstDueDate' => '2026-06-01',
        ])->assertCreated()->json('data.uuid');
    }
}
