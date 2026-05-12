<?php

namespace Tests\Unit\Services;

use App\Contracts\Services\PlanServiceInterface;
use App\Models\Customer;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PlanServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_plan_creation_generates_installments(): void
    {
        $customer = Customer::factory()->create();
        $product = Product::factory()->create();

        $service = app(PlanServiceInterface::class);

        $plan = $service->create([
            'customer_uuid' => $customer->uuid,
            'product_uuid' => $product->uuid,
            'quantity' => 1,
            'unit_price' => 12000,
            'total_amount' => 12000,
            'deposit_amount' => 2000,
            'installment_amount' => 2000,
            'installment_count' => 5,
            'frequency_days' => 30,
            'start_date' => '2026-01-01',
            'notes' => 'Test plan',
            'status' => 'active',
            'is_deleted' => false,
        ]);

        $this->assertCount(5, $plan->installments);
        $this->assertEquals(1, $plan->installments->first()->sequence_number);
        $this->assertEquals('2026-01-01', $plan->installments->first()->scheduled_due_date->toDateString());
    }
}
