<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'card_no' => $this->card_no,
            'name' => $this->name,
            'phone' => $this->phone,
            'cnic' => $this->cnic,
            'address' => $this->address,
            'reference' => $this->reference,
            'plans' => PlanResource::collection($this->whenLoaded('plans')),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
            'users' => UserResource::collection($this->whenLoaded('users')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
