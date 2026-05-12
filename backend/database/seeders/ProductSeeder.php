<?php

namespace Database\Seeders;

use App\Models\Product;
use App\Models\ProductCategory;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        $categories = ProductCategory::query()->get();

        Product::factory()->count(8)->create()->each(function (Product $product) use ($categories): void {
            $product->categories()->sync($categories->random(rand(1, min(3, $categories->count())))->pluck('uuid')->all());
        });
    }
}
