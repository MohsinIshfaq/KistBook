<?php

namespace App\Models;

use App\Enums\AccessLevel;
use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable([
    'uuid',
    'phone',
    'email',
    'password',
    'first_name',
    'last_name',
    'access_level',
    'is_active',
    'is_deleted',
])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens;
    use HasFactory;
    use HasUuid;
    use LogsSyncChanges;
    use Notifiable;

    public function customers(): BelongsToMany
    {
        return $this->belongsToMany(Customer::class, 'user_customer_access', 'user_uuid', 'customer_uuid', 'uuid', 'uuid')
            ->withPivot(['uuid', 'is_deleted'])
            ->withTimestamps();
    }

    public function plans(): BelongsToMany
    {
        return $this->belongsToMany(Plan::class, 'user_plan_access', 'user_uuid', 'plan_uuid', 'uuid', 'uuid')
            ->withPivot(['uuid', 'is_deleted'])
            ->withTimestamps();
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class, 'created_by', 'uuid');
    }

    protected function casts(): array
    {
        return [
            'access_level' => AccessLevel::class,
            'is_active' => 'boolean',
            'is_deleted' => 'boolean',
            'password' => 'hashed',
        ];
    }
}
