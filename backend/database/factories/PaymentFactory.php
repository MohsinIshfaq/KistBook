<?php

namespace Database\Factories;

use App\Models\Installment;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Payment>
 */
class PaymentFactory extends Factory
{
    protected $model = Payment::class;

    public function definition(): array
    {
        $installment = Installment::factory()->create();
        $plan = $installment->plan;
        $user = User::factory()->create();

        return [
            'uuid' => (string) Str::uuid(),
            'operation_uuid' => (string) Str::uuid(),
            'customer_uuid' => $plan->customer_uuid,
            'plan_uuid' => $plan->uuid,
            'installment_uuid' => $installment->uuid,
            'amount' => fake()->randomFloat(2, 100, (float) $installment->amount),
            'paid_on' => now()->toDateString(),
            'note' => fake()->sentence(),
            'source' => 'seed',
            'created_by' => $user->uuid,
            'is_deleted' => false,
        ];
    }
}
