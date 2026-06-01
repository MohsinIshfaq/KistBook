<?php

namespace App\Models;

use App\Enums\PlanStatus;
use App\Traits\BelongsToCompany;
use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Plan extends Model
{
    use BelongsToCompany;
    use HasFactory;
    use HasUuid;
    use LogsSyncChanges;
    use SoftDeletes;

    protected $fillable = [
        'uuid',
        'company_id',
        'customer_uuid',
        'product_uuid',
        'mode',
        'quantity',
        'unit_price',
        'total_amount',
        'deposit_amount',
        'remaining_amount',
        'installment_amount',
        'installment_count',
        'frequency_days',
        'start_date',
        'notes',
        'status',
        'is_deleted',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'unit_price' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'deposit_amount' => 'decimal:2',
            'remaining_amount' => 'decimal:2',
            'installment_amount' => 'decimal:2',
            'installment_count' => 'integer',
            'frequency_days' => 'integer',
            'start_date' => 'date',
            'status' => PlanStatus::class,
            'is_deleted' => 'boolean',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_uuid', 'uuid');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'product_uuid', 'uuid');
    }

    public function installments(): HasMany
    {
        return $this->hasMany(Installment::class, 'plan_uuid', 'uuid');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class, 'plan_uuid', 'uuid');
    }

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'user_plan_access', 'plan_uuid', 'user_uuid', 'uuid', 'uuid')
            ->withPivot(['uuid', 'is_deleted'])
            ->withTimestamps();
    }

    public function items(): HasMany
    {
        return $this->hasMany(InstallmentPlanItem::class, 'plan_uuid', 'uuid');
    }
}
