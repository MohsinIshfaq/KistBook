<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'operationId' => $this->operation_uuid,
            'customerId' => $this->customer_uuid,
            'planId' => $this->plan_uuid,
            'installmentId' => $this->installment_uuid,
            'amount' => (float) $this->amount,
            'paidOn' => $this->paid_on,
            'note' => $this->note,
            'source' => $this->source,
            'createdBy' => $this->created_by,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'plan' => new PlanResource($this->whenLoaded('plan')),
            'installment' => new InstallmentResource($this->whenLoaded('installment')),
            'creator' => new UserResource($this->whenLoaded('creator')),
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
        ];
    }
}
