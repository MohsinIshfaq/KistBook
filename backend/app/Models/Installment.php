<?php

namespace App\Models;

use App\Enums\InstallmentStatus;
use App\Traits\BelongsToCompany;
use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Installment extends Model
{
    use BelongsToCompany;
    use HasFactory;
    use HasUuid;
    use LogsSyncChanges;
    use SoftDeletes;

    protected $fillable = [
        'uuid',
        'company_id',
        'plan_uuid',
        'sequence_number',
        'scheduled_due_date',
        'current_due_date',
        'amount',
        'paid_amount',
        'status',
        'is_deleted',
    ];

    protected function casts(): array
    {
        return [
            'sequence_number' => 'integer',
            'scheduled_due_date' => 'date',
            'current_due_date' => 'date',
            'amount' => 'decimal:2',
            'paid_amount' => 'decimal:2',
            'status' => InstallmentStatus::class,
            'is_deleted' => 'boolean',
        ];
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class, 'plan_uuid', 'uuid');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class, 'installment_uuid', 'uuid');
    }
}
