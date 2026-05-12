<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SyncChangeLog extends Model
{
    use HasFactory;

    protected $table = 'sync_change_log';

    protected $fillable = [
        'entity_type',
        'entity_uuid',
        'operation',
        'changed_at',
        'changed_by',
        'version_no',
    ];

    protected function casts(): array
    {
        return [
            'changed_at' => 'datetime',
            'version_no' => 'integer',
        ];
    }
}
