<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstallmentPlanItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'productId' => $this->product_uuid,
            'variantId' => $this->variant_uuid,
            'quantity' => $this->quantity,
            'agreedPrice' => (float) $this->unit_price_snapshot,
            'totalAmount' => (float) $this->total_amount,
            'deposit' => (float) $this->deposit_amount,
            'installmentAmount' => (float) $this->installment_amount,
            'frequencyInDays' => $this->frequency_days,
            'firstDueDate' => $this->first_due_date?->toDateString(),
            'itemName' => $this->item_name,
            'product' => new ProductResource($this->whenLoaded('product')),
            'variant' => new ProductVariantResource($this->whenLoaded('variant')),
            'schedules' => InstallmentResource::collection($this->whenLoaded('schedules')),
        ];
    }
}
