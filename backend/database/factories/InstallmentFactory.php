<?php

namespace Database\Factories;

use App\Enums\InstallmentStatus;
use App\Models\Installment;
use App\Models\Plan;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Installment>
 */
class InstallmentFactory extends Factory
{
    protected $model = Installment::class;

    public function definition(): array
    {
        $amount = fake()->randomFloat(2, 500, 15000);

        return [
            'uuid' => (string) Str::uuid(),
            'plan_uuid' => Plan::factory(),
            'sequence_number' => fake()->numberBetween(1, 12),
            'scheduled_due_date' => now()->toDateString(),
            'current_due_date' => now()->toDateString(),
            'amount' => $amount,
            'paid_amount' => 0,
            'status' => InstallmentStatus::Pending->value,
            'is_deleted' => false,
        ];
    }
}
