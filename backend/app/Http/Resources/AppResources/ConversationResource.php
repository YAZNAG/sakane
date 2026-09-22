<?php

namespace App\Http\Resources\AppResources;

use Auth;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ConversationResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {


        $with = $this->memberOne == $request->user()->id
            ? $this->mTwo
            : $this->mOne;
        $withResource = $with->type->code == "host"
            ? new HostProfileResource($with)
            : new ClientProfileResource($with);

        return [
            "id" => $this->id,
            "with" => $withResource,
            "lastMessage" => new MessageResource($this->lastMessage)
        ];
    }
}
