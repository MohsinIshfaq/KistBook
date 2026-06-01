<?php

namespace Database\Seeders;

use App\Models\ProductCategory;
use App\Models\User;
use Illuminate\Database\Seeder;

class ProductCategorySeeder extends Seeder
{
    public function run(): void
    {
        $companyId = User::query()->where('phone', '03000000001')->value('company_id');

        ProductCategory::factory()->count(5)->create(['company_id' => $companyId]);
    }
}
