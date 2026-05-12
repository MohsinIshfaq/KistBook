<?php

namespace Database\Factories;

use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    protected $model = Product::class;

    public function definition(): array
    {
        return [
            'uuid' => (string) Str::uuid(),
            'brand_name' => fake()->company(),
            'product_name' => fake()->words(2, true),
            'code' => fake()->unique()->bothify('PRD-####'),
            'sales_price' => fake()->randomFloat(2, 1000, 150000),
            'notes' => fake()->sentence(),
            'is_deleted' => false,
        ];
    }
}
