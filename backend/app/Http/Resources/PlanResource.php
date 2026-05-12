<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PlanResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'customer_uuid' => $this->customer_uuid,
            'product_uuid' => $this->product_uuid,
            'quantity' => $this->quantity,
            'unit_price' => (float) $this->unit_price,
            'total_amount' => (float) $this->total_amount,
            'deposit_amount' => (float) $this->deposit_amount,
            'installment_amount' => (float) $this->installment_amount,
            'installment_count' => $this->installment_count,
            'frequency_days' => $this->frequency_days,
            'start_date' => $this->start_date,
            'notes' => $this->notes,
            'status' => $this->status?->value ?? $this->status,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'product' => new ProductResource($this->whenLoaded('product')),
            'installments' => InstallmentResource::collection($this->whenLoaded('installments')),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
            'users' => UserResource::collection($this->whenLoaded('users')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
