<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstallmentPlanResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'customerId' => $this->customer_uuid,
            'mode' => $this->mode,
            'totalAmount' => (float) $this->total_amount,
            'deposit' => (float) $this->deposit_amount,
            'remainingAmount' => (float) $this->remaining_amount,
            'installmentCount' => $this->installment_count,
            'note' => $this->notes,
            'status' => $this->status?->value ?? $this->status,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'selectedProducts' => InstallmentPlanItemResource::collection($this->whenLoaded('items')),
            'schedules' => InstallmentResource::collection($this->whenLoaded('installments')),
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
        ];
    }
}
