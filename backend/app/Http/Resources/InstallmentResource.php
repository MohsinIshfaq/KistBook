<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstallmentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'plan_uuid' => $this->plan_uuid,
            'sequence_number' => $this->sequence_number,
            'scheduled_due_date' => $this->scheduled_due_date,
            'current_due_date' => $this->current_due_date,
            'amount' => (float) $this->amount,
            'paid_amount' => (float) $this->paid_amount,
            'status' => $this->status?->value ?? $this->status,
            'plan' => new PlanResource($this->whenLoaded('plan')),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
