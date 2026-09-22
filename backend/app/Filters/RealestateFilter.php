<?php

namespace App\Filters;

use App\Models\RealstateCategory;


class RealestateFilter extends QueryFilter
{


    public function typeTransaction($type)
    {
        $this->builder->whereHas("type", function ($query) use ($type) {
            $query->where("code", "=", $type);
        });
    }
    public function category($category)
    {
        $this->builder->whereHas("category", function ($query) use ($category) {
            $query->where("code", "=", $category);
        });
    }
    public function city($city)
    {
        $this->builder->where("city_id", "=", $city);
    }

    public function region($region)
    {
        $this->builder->whereHas("city", function ($query) use ($region) {
            $query->where("region_id", "=", $region);
        });
    }


    public function features($featureIds)
    {
        $this->builder->whereHas("features", function ($query) use ($featureIds) {
            $query->whereIn("feature_id", $featureIds);
        }, '>=', count($featureIds));
    }


    public function host($host)
    {
        $this->builder->where("host_id", "=", $host);
    }

    public function etat($etat)
    {
        $this->builder->whereHas("etat", function ($query,) use ($etat) {
            $query->where("code", "=", $etat);
        });
    }
}
