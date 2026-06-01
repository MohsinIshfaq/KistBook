<?php

namespace Database\Factories;

use App\Models\Company;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Company>
 */
class CompanyFactory extends Factory
{
    public function definition(): array
    {
        return [
            'uuid' => (string) Str::uuid(),
            'name' => fake()->company(),
            'phone' => fake()->numerify('03#########'),
            'email' => fake()->unique()->companyEmail(),
            'address' => fake()->address(),
            'status' => 'active',
        ];
    }
}
