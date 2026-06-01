<?php

namespace Database\Seeders;

use App\Contracts\Services\PaymentServiceInterface;
use App\Models\Installment;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class PaymentSeeder extends Seeder
{
    public function run(): void
    {
        $service = app(PaymentServiceInterface::class);
        $user = User::query()->firstOrFail();

        Installment::query()->take(5)->get()->each(function (Installment $installment) use ($service, $user): void {
            $service->create([
                'company_id' => $user->company_id,
                'operation_uuid' => (string) Str::uuid(),
                'customer_uuid' => $installment->plan->customer_uuid,
                'plan_uuid' => $installment->plan_uuid,
                'installment_uuid' => $installment->uuid,
                'amount' => round((float) $installment->amount / 2, 2),
                'paid_on' => now()->toDateString(),
                'note' => 'Demo payment',
                'source' => 'seed',
                'created_by' => $user->uuid,
                'is_deleted' => false,
            ]);
        });
    }
}
