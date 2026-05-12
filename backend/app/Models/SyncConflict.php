<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SyncConflict extends Model
{
    use HasFactory;

    protected $table = 'sync_conflicts';

    protected $fillable = [
        'device_id',
        'entity_type',
        'entity_uuid',
        'local_version',
        'server_version',
        'reason',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'local_version' => 'integer',
            'server_version' => 'integer',
            'resolved_at' => 'datetime',
        ];
    }
}
