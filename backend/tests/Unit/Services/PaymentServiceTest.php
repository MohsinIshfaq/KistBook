<?php

namespace Tests\Unit\Services;

use App\Contracts\Services\PaymentServiceInterface;
use App\Models\Customer;
use App\Models\Installment;
use App\Models\Plan;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class PaymentServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_payment_creation_updates_installment_status_and_is_idempotent(): void
    {
        $user = User::factory()->create();
        $customer = Customer::factory()->create();
        $product = Product::factory()->create();
        $plan = Plan::factory()->create([
            'customer_uuid' => $customer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        $installment = Installment::factory()->create([
            'plan_uuid' => $plan->uuid,
            'amount' => 5000,
            'paid_amount' => 0,
            'current_due_date' => now()->addDay()->toDateString(),
        ]);

        $service = app(PaymentServiceInterface::class);
        $operationUuid = (string) Str::uuid();

        $payment = $service->create([
            'operation_uuid' => $operationUuid,
            'customer_uuid' => $customer->uuid,
            'plan_uuid' => $plan->uuid,
            'installment_uuid' => $installment->uuid,
            'amount' => 5000,
            'paid_on' => now()->toDateString(),
            'note' => 'Full payment',
            'source' => 'test',
            'created_by' => $user->uuid,
            'is_deleted' => false,
        ]);

        $this->assertEquals($operationUuid, $payment->operation_uuid);
        $this->assertEquals('paid', $installment->refresh()->status->value);
        $this->assertEquals(5000.0, (float) $installment->paid_amount);

        $duplicate = $service->create([
            'operation_uuid' => $operationUuid,
            'customer_uuid' => $customer->uuid,
            'plan_uuid' => $plan->uuid,
            'installment_uuid' => $installment->uuid,
            'amount' => 5000,
            'paid_on' => now()->toDateString(),
            'note' => 'Duplicate payment',
            'source' => 'test',
            'created_by' => $user->uuid,
            'is_deleted' => false,
        ]);

        $this->assertTrue($payment->is($duplicate));
        $this->assertDatabaseCount('payments', 1);
    }
}
