<?php

namespace Database\Seeders;

use App\Contracts\Services\PlanServiceInterface;
use App\Models\Customer;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Seeder;

class PlanSeeder extends Seeder
{
    public function run(): void
    {
        $service = app(PlanServiceInterface::class);
        $customers = Customer::query()->take(5)->get();
        $products = Product::query()->take(5)->get();
        $companyId = User::query()->where('phone', '03000000001')->value('company_id');

        foreach ($customers as $index => $customer) {
            $product = $products[$index % $products->count()];
            $quantity = rand(1, 3);
            $unitPrice = (float) $product->sales_price;
            $total = $quantity * $unitPrice;
            $deposit = round($total * 0.2, 2);
            $installmentCount = 6;

            $service->create([
                'company_id' => $companyId,
                'customer_uuid' => $customer->uuid,
                'product_uuid' => $product->uuid,
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'total_amount' => $total,
                'deposit_amount' => $deposit,
                'installment_amount' => round(($total - $deposit) / $installmentCount, 2),
                'installment_count' => $installmentCount,
                'frequency_days' => 30,
                'start_date' => now()->subMonths(rand(0, 3))->toDateString(),
                'notes' => 'Demo purchase plan',
                'status' => 'active',
                'is_deleted' => false,
            ]);
        }
    }
}
