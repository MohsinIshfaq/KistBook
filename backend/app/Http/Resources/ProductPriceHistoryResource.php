<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductPriceHistoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'previousPrice' => $this->previous_price === null ? null : (float) $this->previous_price,
            'newPrice' => (float) $this->new_price,
            'changedAt' => $this->changed_at?->toJSON(),
            'source' => $this->source,
        ];
    }
}
