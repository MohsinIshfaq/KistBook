<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'cardNumber' => $this->card_no,
            'customerName' => $this->name,
            'phoneNumber' => $this->phone,
            'cnic' => $this->cnic,
            'address' => $this->address,
            'reference' => $this->reference,
            'customerImage' => $this->image_disk && $this->image_path ? Storage::disk($this->image_disk)->url($this->image_path) : null,
            'isDeleted' => (bool) $this->is_deleted,
            'deletedAt' => $this->deleted_at,
            'plans' => PlanResource::collection($this->whenLoaded('plans')),
            'payments' => PaymentResource::collection($this->whenLoaded('payments')),
            'users' => UserResource::collection($this->whenLoaded('users')),
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
        ];
    }
}
