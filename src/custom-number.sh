#!/usr/bin/env bash

format_for_name() {
    case "$1" in
        hide)
            printf ''
            ;;
        digital|arabic)
            printf '0123456789'
            ;;
        fsquare)
            printf '󰎡󰎤󰎧󰎪󰎭󰎱󰎳󰎶󰎹󰎼'
            ;;
        hsquare)
            printf '󰎣󰎦󰎩󰎬󰎮󰎰󰎵󰎸󰎻󰎾'
            ;;
        dsquare)
            printf '󰎢󰎥󰎨󰎫󰎲󰎯󰎴󰎷󰎺󰎽'
            ;;
        super)
            printf '⁰¹²³⁴⁵⁶⁷⁸⁹'
            ;;
        sub)
            printf '₀₁₂₃₄₅₆₇₈₉'
            ;;
        earabic)
            printf '٠١٢٣٤٥٦٧٨٩'
            ;;
        *)
            return 1
            ;;
    esac
}

ID="$1"
FORMAT="${2:-none}"

if [[ "$FORMAT" == "hide" ]]; then
    exit 0
fi

if ! format_str="$(format_for_name "$FORMAT")"; then
    echo "Invalid format: $FORMAT" >&2
    exit 1
fi

result=""

for ((i = 0; i < ${#ID}; i++)); do
    digit="${ID:$i:1}"
    char="${format_str:$digit:1}"
    result+="${char} "
done

echo -n "$result"
