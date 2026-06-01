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
            'customerId' => $this->customer_uuid,
            'productId' => $this->product_uuid,
            'quantity' => $this->quantity,
            'unitPrice' => (float) $this->unit_price,
            'totalAmount' => (float) $this->total_amount,
            'depositAmount' => (float) $this->deposit_amount,
            'remainingAmount' => (float) $this->remaining_amount,
            'installmentAmount' => (float) $this->installment_amount,
            'installmentCount' => $this->installment_count,
            'frequencyInDays' => $this->frequency_days,
            'firstDueDate' => $this->start_date,
            'note' => $this->notes,
            'status' => $this->status?->value ?? $this->status,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'product' => new ProductResource($this->whenLoaded('product')),
            'installments' => InstallmentResource::collection($this->whenLoaded('installments')),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
            'users' => UserResource::collection($this->whenLoaded('users')),
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
        ];
    }
}
