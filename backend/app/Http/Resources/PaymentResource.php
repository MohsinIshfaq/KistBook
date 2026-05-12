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
            'operation_uuid' => $this->operation_uuid,
            'customer_uuid' => $this->customer_uuid,
            'plan_uuid' => $this->plan_uuid,
            'installment_uuid' => $this->installment_uuid,
            'amount' => (float) $this->amount,
            'paid_on' => $this->paid_on,
            'note' => $this->note,
            'source' => $this->source,
            'created_by' => $this->created_by,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'plan' => new PlanResource($this->whenLoaded('plan')),
            'installment' => new InstallmentResource($this->whenLoaded('installment')),
            'creator' => new UserResource($this->whenLoaded('creator')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
