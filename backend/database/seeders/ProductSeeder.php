<?php

namespace Database\Seeders;

use App\Models\Product;
use App\Models\ProductCategory;
use App\Models\User;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        $categories = ProductCategory::query()->get();
        $companyId = User::query()->where('phone', '03000000001')->value('company_id');

        Product::factory()->count(8)->create(['company_id' => $companyId])->each(function (Product $product) use ($categories): void {
            $product->categories()->sync($categories->random(rand(1, min(3, $categories->count())))->pluck('uuid')->all());
        });
    }
}
