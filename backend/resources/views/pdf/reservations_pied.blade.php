@if (!empty($totaux))<tr class="total">@foreach ($totaux as $i => $c)<td class="{{ $i >= 10 && $i <= 13 ? 'num' : '' }}">{{ $i >= 10 && $i <= 13 ? number_format((float) $c, 2, ',', ' ') : $c }}</td>@endforeach</tr>
</tbody></table>@endif
<div class="pied">{{ $agence }}</div>
