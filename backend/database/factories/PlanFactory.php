<?php

namespace Database\Factories;

use App\Enums\PlanStatus;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Plan>
 */
class PlanFactory extends Factory
{
    protected $model = Plan::class;

    public function definition(): array
    {
        $quantity = fake()->numberBetween(1, 3);
        $unitPrice = fake()->randomFloat(2, 1000, 150000);
        $total = $quantity * $unitPrice;
        $deposit = fake()->randomFloat(2, 0, $total / 3);
        $count = fake()->numberBetween(3, 12);

        return [
            'uuid' => (string) Str::uuid(),
            'customer_uuid' => Customer::factory(),
            'product_uuid' => Product::factory(),
            'quantity' => $quantity,
            'unit_price' => $unitPrice,
            'total_amount' => $total,
            'deposit_amount' => $deposit,
            'installment_amount' => max(1, round(($total - $deposit) / $count, 2)),
            'installment_count' => $count,
            'frequency_days' => 30,
            'start_date' => now()->toDateString(),
            'notes' => fake()->sentence(),
            'status' => PlanStatus::Active->value,
            'is_deleted' => false,
        ];
    }
}
