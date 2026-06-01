<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\Installment;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class InstallmentPlanApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_common_plan_generates_aggregate_schedule_with_final_remainder(): void
    {
        [$customer, $product] = $this->records();

        $response = $this->postJson('/api/installment-plans', [
            'customerId' => $customer->uuid,
            'mode' => 'common',
            'selectedProducts' => [[
                'productId' => $product->uuid,
                'quantity' => 1,
            ]],
            'commonDeposit' => 100,
            'commonInstallmentAmount' => 350,
            'commonFrequencyInDays' => 30,
            'commonFirstDueDate' => '2026-06-01',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.totalAmount', 1000)
            ->assertJsonPath('data.remainingAmount', 900)
            ->assertJsonCount(3, 'data.schedules')
            ->assertJsonPath('data.schedules.2.amount', 200);
    }

    public function test_separate_plan_generates_schedule_per_item(): void
    {
        [$customer, $first] = $this->records();
        $second = Product::factory()->create(['base_price' => 600, 'sales_price' => 600]);

        $response = $this->postJson('/api/installment-plans', [
            'customerId' => $customer->uuid,
            'mode' => 'separate',
            'selectedProducts' => [
                [
                    'productId' => $first->uuid,
                    'deposit' => 100,
                    'installmentAmount' => 450,
                    'frequencyInDays' => 30,
                    'firstDueDate' => '2026-06-01',
                ],
                [
                    'productId' => $second->uuid,
                    'agreedPrice' => 500,
                    'deposit' => 0,
                    'installmentAmount' => 300,
                    'frequencyInDays' => 15,
                    'firstDueDate' => '2026-06-05',
                ],
            ],
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.totalAmount', 1500)
            ->assertJsonPath('data.deposit', 100)
            ->assertJsonCount(2, 'data.selectedProducts')
            ->assertJsonCount(4, 'data.schedules');
        $this->assertSame(4, collect($response->json('data.schedules'))->where('scheduleGroup', 'item')->count());
    }

    public function test_update_preserves_paid_schedule_and_rebuilds_future_rows(): void
    {
        [$customer, $product] = $this->records();
        $payload = [
            'customerId' => $customer->uuid,
            'mode' => 'common',
            'selectedProducts' => [['productId' => $product->uuid]],
            'commonDeposit' => 100,
            'commonInstallmentAmount' => 300,
            'commonFrequencyInDays' => 30,
            'commonFirstDueDate' => '2026-06-01',
        ];
        $create = $this->postJson('/api/installment-plans', $payload)->assertCreated();
        $planUuid = $create->json('data.uuid');
        $paidUuid = $create->json('data.schedules.0.uuid');
        Installment::query()->where('uuid', $paidUuid)->firstOrFail()->forceFill([
            'paid_amount' => 300,
            'status' => 'paid',
        ])->save();

        $payload['commonInstallmentAmount'] = 200;
        $this->putJson('/api/installment-plans/'.$planUuid, $payload)
            ->assertOk()
            ->assertJsonPath('data.schedules.0.uuid', $paidUuid)
            ->assertJsonCount(4, 'data.schedules');

        $this->assertDatabaseHas('installments', [
            'uuid' => $paidUuid,
            'deleted_at' => null,
            'paid_amount' => 300,
        ]);
    }

    private function records(): array
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        return [
            Customer::factory()->create(['company_id' => $owner->company_id]),
            Product::factory()->create(['base_price' => 1000, 'sales_price' => 1000]),
        ];
    }
}
