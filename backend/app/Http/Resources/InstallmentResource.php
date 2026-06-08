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
            'planId' => $this->plan_uuid,
            'planItemId' => $this->plan_item_uuid,
            'scheduleGroup' => $this->schedule_group,
            'sequenceNumber' => $this->sequence_number,
            'itemSequenceNumber' => $this->item_sequence_number,
            'scheduledDueDate' => $this->scheduled_due_date,
            'currentDueDate' => $this->current_due_date,
            'previousDueDate' => $this->previous_due_date,
            'amount' => (float) $this->amount,
            'paidAmount' => (float) $this->paid_amount,
            'status' => $this->status?->value ?? $this->status,
            'rescheduleNote' => $this->reschedule_note,
            'rescheduledAt' => $this->rescheduled_at,
            'plan' => new PlanResource($this->whenLoaded('plan')),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
        ];
    }
}
