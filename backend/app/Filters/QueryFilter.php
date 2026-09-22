<?php

namespace App\Filters;

use Illuminate\Http\Request;
use Illuminate\Database\Eloquent\Builder;

class QueryFilter
{
    protected Request $request;
    protected Builder $builder;

    public function __construct(Request $request)
    {
        $this->request = $request;
    }

    public function filter($builder) {
        $this->builder=$builder;
        foreach($this->request->all() as $key=>$value){
            if(method_exists($this,$key)){
                $this->$key($value);
            }
        }
        return $this->builder;
    }
}
