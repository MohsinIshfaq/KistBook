<?php

namespace Database\Factories;

use App\Models\Customer;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Customer>
 */
class CustomerFactory extends Factory
{
    protected $model = Customer::class;

    public function definition(): array
    {
        return [
            'uuid' => (string) Str::uuid(),
            'card_no' => fake()->unique()->numerify('CARD-####'),
            'name' => fake()->name(),
            'phone' => fake()->phoneNumber(),
            'cnic' => fake()->unique()->numerify('#####-#######-#'),
            'address' => fake()->address(),
            'reference' => fake()->name(),
            'is_deleted' => false,
        ];
    }
}
