<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppVersion extends Model
{
    protected $fillable = [
        'package_name',
        'version',
        'apk_url',
        'description',
        'is_active',
    ];
}
