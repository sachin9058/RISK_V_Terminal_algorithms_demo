#!/usr/bin/env bash
set -euo pipefail

# Step-by-step Tower of Hanoi simulation with compact ASCII graphics.
# Recursion: hanoi(). Iteration: loops in print_state().

N="${1:-4}"
SLEEP="${2:-0.35}"

if ! [[ "$N" =~ ^[0-9]+$ ]] || (( N < 1 || N > 8 )); then
  echo "Usage: $0 [discs: 1-8] [delay_seconds]"
  exit 1
fi

declare -a A=() B=() C=()
move_count=0
last_move="Start"
last_disk=0
last_from=""
last_to=""
frame=0
total_moves=$((2**N - 1))

RESET=""
BOLD=""
DIM=""
ROD_A=""
ROD_B=""
ROD_C=""
HIGHLIGHT=""
DISC_1=""
DISC_2=""
DISC_3=""
DISC_4=""
DISC_5=""
DISC_6=""
DISC_7=""
DISC_8=""

supports_color() {
  [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]
}

setup_colors() {
  if supports_color; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'

    ROD_A=$'\033[38;5;203m'
    ROD_B=$'\033[38;5;150m'
    ROD_C=$'\033[38;5;117m'
    HIGHLIGHT=$'\033[48;5;236m\033[1m'

    DISC_1=$'\033[38;5;225m'
    DISC_2=$'\033[38;5;218m'
    DISC_3=$'\033[38;5;214m'
    DISC_4=$'\033[38;5;221m'
    DISC_5=$'\033[38;5;157m'
    DISC_6=$'\033[38;5;123m'
    DISC_7=$'\033[38;5;117m'
    DISC_8=$'\033[38;5;111m'
  fi
}

repeat_char() {
  local ch="$1"
  local count="$2"
  local out=""
  for ((i=0; i<count; i++)); do
    out+="$ch"
  done
  printf '%s' "$out"
}

draw_disc() {
  local size="$1"
  if (( size == 0 )); then
    printf '%s' "|"
    return
  fi

  # Simple visual weight: larger discs have wider bars.
  local bar
  bar=$(repeat_char "=" $((size * 2 - 1)))
  printf '%s' "$bar"
}

rod_color() {
  local rod="$1"
  case "$rod" in
    A) printf '%s' "$ROD_A" ;;
    B) printf '%s' "$ROD_B" ;;
    C) printf '%s' "$ROD_C" ;;
    *) printf '%s' "" ;;
  esac
}

disc_color() {
  local size="$1"
  case "$size" in
    1) printf '%s' "$DISC_1" ;;
    2) printf '%s' "$DISC_2" ;;
    3) printf '%s' "$DISC_3" ;;
    4) printf '%s' "$DISC_4" ;;
    5) printf '%s' "$DISC_5" ;;
    6) printf '%s' "$DISC_6" ;;
    7) printf '%s' "$DISC_7" ;;
    8) printf '%s' "$DISC_8" ;;
    *) printf '%s' "" ;;
  esac
}

progress_bar() {
  local width=28
  local filled=$(( move_count * width / total_moves ))
  local empty=$(( width - filled ))
  local fill
  local gap
  fill=$(repeat_char "#" "$filled")
  gap=$(repeat_char "." "$empty")
  printf '[%s%s]' "$fill" "$gap"
}

render_slot() {
  local disc="$1"
  local rod="$2"
  local width=$((N * 2 - 1))

  local shape
  shape=$(draw_disc "$disc")
  local pad=$(( (width - ${#shape}) / 2 ))
  if (( pad < 0 )); then pad=0; fi

  local color
  if (( disc == 0 )); then
    color="$(rod_color "$rod")$DIM"
  else
    color="$(disc_color "$disc")"
  fi

  local style=""
  if [[ "$rod" == "$last_to" ]] && (( disc == last_disk )) && (( move_count > 0 )); then
    style="$HIGHLIGHT"
  fi

  printf '%*s%s%s%s%s%*s' "$pad" '' "$style" "$color" "$shape" "$RESET" "$pad" ''
}

print_state() {
  clear || true
  local spin='|/-\\'
  local spin_char="${spin:frame%4:1}"
  ((++frame))

  local header_bar
  header_bar=$(repeat_char "=" $((N * 8 + 7)))

  echo "${BOLD}${header_bar}${RESET}"
  echo "${BOLD} Tower of Hanoi Simulation ${spin_char}${RESET}"
  echo " Discs: $N   Moves: $move_count / $total_moves"
  printf ' Progress: %s %3d%%\n' "$(progress_bar)" "$(( move_count * 100 / total_moves ))"
  echo " Last move: $last_move"
  echo "${BOLD}${header_bar}${RESET}"
  echo

  # Iteration: draw each visual row from top to bottom.
  for ((row=N-1; row>=0; row--)); do
    local a=0 b=0 c=0
    if (( row < ${#A[@]} )); then a=${A[$row]}; fi
    if (( row < ${#B[@]} )); then b=${B[$row]}; fi
    if (( row < ${#C[@]} )); then c=${C[$row]}; fi

    render_slot "$a" A
    printf '   '
    render_slot "$b" B
    printf '   '
    render_slot "$c" C
    echo
  done

  local base
  base=$(repeat_char "-" $((N * 2 - 1)))
  printf '%s%s%s%s%s%s%s%s%s\n' "$ROD_A" "$base" "$RESET" '   ' "$ROD_B" "$base" "$RESET" '   ' "$ROD_C$base$RESET"
  printf '%s%*sA%*s%s   %s%*sB%*s%s   %s%*sC%*s%s\n' "$ROD_A" "$((N-1))" '' "$((N-1))" '' "$RESET" "$ROD_B" "$((N-1))" '' "$((N-1))" '' "$RESET" "$ROD_C" "$((N-1))" '' "$((N-1))" '' "$RESET"

  sleep "$SLEEP"
}

move_disk() {
  local from_name="$1"
  local to_name="$2"
  local -n from_ref="$from_name"
  local -n to_ref="$to_name"

  local top_idx=$(( ${#from_ref[@]} - 1 ))
  local disk="${from_ref[$top_idx]}"
  unset 'from_ref[$top_idx]'
  to_ref+=("$disk")

  ((++move_count))
  last_disk="$disk"
  last_from="$from_name"
  last_to="$to_name"
  last_move="Move $move_count: $disk from $from_name -> $to_name"

  # Short micro-pause before redraw helps the move feel more animated.
  if [[ "$SLEEP" != "0" ]]; then
    sleep 0.04
  fi
  print_state
}

hanoi() {
  local n="$1"
  local from="$2"
  local to="$3"
  local aux="$4"

  # Recursion base case.
  if (( n == 1 )); then
    move_disk "$from" "$to"
    return
  fi

  # Recursion step.
  hanoi $((n - 1)) "$from" "$aux" "$to"
  move_disk "$from" "$to"
  hanoi $((n - 1)) "$aux" "$to" "$from"
}

for ((d=N; d>=1; d--)); do
  A+=("$d")
done

setup_colors
print_state
hanoi "$N" A C B

echo
echo "${BOLD}Solved in $move_count moves.${RESET}"
