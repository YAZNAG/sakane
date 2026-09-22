<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MessageResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    private bool $isEventObject = false;
    public function withEvent($isEvent)
    {
        $this->isEventObject = true;
        return $this;
    }
    public function toArray(Request $request): array
    {
        $imSender = $request->user()->id == $this->sender_id;
        $with = $this->isEventObject
            ? $this->sender
            : ($imSender ? $this->receiver : $this->sender);
        $withResource = $with->type->code == "host" ? new HostProfileResource($with) : new ClientProfileResource($with);
        return [
            "id" => $this->id,
            "text" => $this->text,
            "with" => $withResource,
            "imSender" => $this->isEventObject ? false : $imSender,
            "date" => $this->created_at
        ];
    }
}
