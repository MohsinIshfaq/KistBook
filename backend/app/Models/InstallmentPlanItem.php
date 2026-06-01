<?php

namespace App\Models;

use App\Traits\BelongsToCompany;
use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class InstallmentPlanItem extends Model
{
    use BelongsToCompany;
    use HasUuid;
    use LogsSyncChanges;
    use SoftDeletes;

    protected $fillable = [
        'uuid',
        'company_id',
        'plan_uuid',
        'product_uuid',
        'variant_uuid',
        'quantity',
        'unit_price_snapshot',
        'total_amount',
        'deposit_amount',
        'installment_amount',
        'frequency_days',
        'first_due_date',
        'item_name',
        'is_deleted',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'unit_price_snapshot' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'deposit_amount' => 'decimal:2',
            'installment_amount' => 'decimal:2',
            'frequency_days' => 'integer',
            'first_due_date' => 'date',
            'is_deleted' => 'boolean',
        ];
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class, 'plan_uuid', 'uuid');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'product_uuid', 'uuid');
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'variant_uuid', 'uuid');
    }

    public function schedules(): HasMany
    {
        return $this->hasMany(Installment::class, 'plan_item_uuid', 'uuid');
    }
}
