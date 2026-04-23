#!/usr/bin/env bash
set -euo pipefail

# Conway's Game of Life (terminal edition)
# Iteration is the core mechanic: nested loops update every cell each generation.

DEMO_MODE=0
if [[ "${1:-}" == "--demo" ]]; then
  DEMO_MODE=1
  shift
fi

if (( DEMO_MODE == 1 )); then
  ROWS="${1:-22}"
  COLS="${2:-56}"
  SPEED="${3:-0.06}"
  MAX_GEN="${4:-220}"
  PATTERN="${5:-acorn}"
  WRAP="${6:-1}"
else
  ROWS="${1:-20}"
  COLS="${2:-40}"
  SPEED="${3:-0.14}"
  MAX_GEN="${4:-0}"
  PATTERN="${5:-glider}"
  WRAP="${6:-1}"
fi

if ! [[ "$ROWS" =~ ^[0-9]+$ ]] || ! [[ "$COLS" =~ ^[0-9]+$ ]] || (( ROWS < 5 || COLS < 5 )); then
  echo "Usage: $0 [--demo] [rows>=5] [cols>=5] [speed] [max_gen:0=forever] [pattern:glider|blinker|acorn|random] [wrap:0|1]"
  exit 1
fi
if ! [[ "$MAX_GEN" =~ ^[0-9]+$ ]]; then
  echo "max_gen must be a non-negative integer"
  exit 1
fi
if ! [[ "$WRAP" =~ ^[01]$ ]]; then
  echo "wrap must be 0 or 1"
  exit 1
fi

declare -A grid=()
declare -A age=()
declare -A seen_signatures=()
generation=0
live_cells=0
births=0
deaths=0
survivors=0
stop_reason=""

RESET=""
BOLD=""
DIM=""
TITLE=""
STAT=""
ALIVE_1=""
ALIVE_2=""
ALIVE_3=""
ALIVE_4=""
DEAD_COLOR=""

supports_color() {
  [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]
}

setup_theme() {
  if supports_color; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    TITLE=$'\033[38;5;213m\033[1m'
    STAT=$'\033[38;5;153m'
    ALIVE_1=$'\033[38;5;84m'
    ALIVE_2=$'\033[38;5;120m'
    ALIVE_3=$'\033[38;5;194m'
    ALIVE_4=$'\033[38;5;226m\033[1m'
    DEAD_COLOR=$'\033[38;5;238m'
  fi
}

repeat_char() {
  local ch="$1"
  local count="$2"
  local out=""
  for ((k=0; k<count; k++)); do
    out+="$ch"
  done
  printf '%s' "$out"
}

set_cell() {
  local r="$1"
  local c="$2"
  local v="$3"
  if (( r >= 0 && r < ROWS && c >= 0 && c < COLS )); then
    grid[$r,$c]="$v"
    if (( v == 1 )); then
      age[$r,$c]=1
    else
      age[$r,$c]=0
    fi
  fi
}

clear_grid() {
  for ((r=0; r<ROWS; r++)); do
    for ((c=0; c<COLS; c++)); do
      grid[$r,$c]=0
      age[$r,$c]=0
    done
  done
}

randomize_grid() {
  for ((r=0; r<ROWS; r++)); do
    for ((c=0; c<COLS; c++)); do
      local v=0
      if (( RANDOM % 100 < 28 )); then v=1; fi
      grid[$r,$c]="$v"
      age[$r,$c]="$v"
    done
  done
}

seed_pattern() {
  local pattern="$1"
  clear_grid

  local cx=$((ROWS / 2))
  local cy=$((COLS / 2))

  case "$pattern" in
    glider)
      set_cell $((cx - 1)) "$cy" 1
      set_cell "$cx" $((cy + 1)) 1
      set_cell $((cx + 1)) $((cy - 1)) 1
      set_cell $((cx + 1)) "$cy" 1
      set_cell $((cx + 1)) $((cy + 1)) 1
      ;;
    blinker)
      set_cell "$cx" $((cy - 1)) 1
      set_cell "$cx" "$cy" 1
      set_cell "$cx" $((cy + 1)) 1
      ;;
    acorn)
      set_cell "$cx" $((cy + 1)) 1
      set_cell $((cx + 1)) $((cy + 3)) 1
      set_cell $((cx + 2)) $((cy - 1)) 1
      set_cell $((cx + 2)) "$cy" 1
      set_cell $((cx + 2)) $((cy + 3)) 1
      set_cell $((cx + 2)) $((cy + 4)) 1
      set_cell $((cx + 2)) $((cy + 5)) 1
      ;;
    random)
      randomize_grid
      ;;
    *)
      echo "Unknown pattern: $pattern (use glider|blinker|acorn|random)"
      exit 1
      ;;
  esac
}

count_live_cells() {
  local count=0
  for ((r=0; r<ROWS; r++)); do
    for ((c=0; c<COLS; c++)); do
      count=$((count + ${grid[$r,$c]:-0}))
    done
  done
  printf '%s' "$count"
}

count_neighbors() {
  local x="$1"
  local y="$2"
  local count=0

  for dx in -1 0 1; do
    for dy in -1 0 1; do
      (( dx == 0 && dy == 0 )) && continue

      local nx=$((x + dx))
      local ny=$((y + dy))

      if (( WRAP == 1 )); then
        nx=$(( (nx + ROWS) % ROWS ))
        ny=$(( (ny + COLS) % COLS ))
        count=$((count + ${grid[$nx,$ny]:-0}))
      else
        if (( nx >= 0 && nx < ROWS && ny >= 0 && ny < COLS )); then
          count=$((count + ${grid[$nx,$ny]:-0}))
        fi
      fi
    done
  done

  printf '%s' "$count"
}

cell_style() {
  local is_alive="$1"
  local cell_age="$2"

  if (( is_alive == 0 )); then
    printf '%s..%s' "$DEAD_COLOR" "$RESET"
    return
  fi

  if (( cell_age <= 2 )); then
    printf '%s[]%s' "$ALIVE_1" "$RESET"
  elif (( cell_age <= 5 )); then
    printf '%s[]%s' "$ALIVE_2" "$RESET"
  elif (( cell_age <= 8 )); then
    printf '%s[]%s' "$ALIVE_3" "$RESET"
  else
    printf '%s[]%s' "$ALIVE_4" "$RESET"
  fi
}

print_grid() {
  clear || true
  local spin='|/-\\'
  local spin_char="${spin:generation%4:1}"
  local border
  border=$(repeat_char "=" $((COLS * 2 + 2)))

  echo "${TITLE}${border}${RESET}"
  echo "${TITLE} Conway's Game of Life ${spin_char}${RESET}"
  echo "${STAT} Generation: $generation   Live: $live_cells   Births: $births   Deaths: $deaths   Survivors: $survivors${RESET}"
  echo "${DIM} Pattern: $PATTERN   Wrap: $WRAP   Grid: ${ROWS}x${COLS}   Ctrl+C to stop${RESET}"
  echo "${TITLE}${border}${RESET}"

  for ((r=0; r<ROWS; r++)); do
    printf '%s|%s' "$DIM" "$RESET"
    for ((c=0; c<COLS; c++)); do
      local v="${grid[$r,$c]:-0}"
      local a="${age[$r,$c]:-0}"
      cell_style "$v" "$a"
    done
    printf '%s|%s\n' "$DIM" "$RESET"
  done

  echo "${DIM}${border}${RESET}"
}

step_generation() {
  declare -A next=()
  declare -A next_age=()

  births=0
  deaths=0
  survivors=0

  # Iteration: evaluate each cell against the Game of Life rules.
  for ((r=0; r<ROWS; r++)); do
    for ((c=0; c<COLS; c++)); do
      local current="${grid[$r,$c]:-0}"
      local neighbors
      neighbors=$(count_neighbors "$r" "$c")

      if (( current == 1 )); then
        if (( neighbors == 2 || neighbors == 3 )); then
          next[$r,$c]=1
          next_age[$r,$c]=$(( ${age[$r,$c]:-0} + 1 ))
          ((++survivors))
        else
          next[$r,$c]=0
          next_age[$r,$c]=0
          ((++deaths))
        fi
      else
        if (( neighbors == 3 )); then
          next[$r,$c]=1
          next_age[$r,$c]=1
          ((++births))
        else
          next[$r,$c]=0
          next_age[$r,$c]=0
        fi
      fi
    done
  done

  grid=()
  age=()
  for ((r=0; r<ROWS; r++)); do
    for ((c=0; c<COLS; c++)); do
      grid[$r,$c]="${next[$r,$c]:-0}"
      age[$r,$c]="${next_age[$r,$c]:-0}"
    done
  done

  live_cells=$(count_live_cells)
}

grid_signature() {
  local sig=""
  for ((r=0; r<ROWS; r++)); do
    for ((c=0; c<COLS; c++)); do
      sig+="${grid[$r,$c]:-0}"
    done
  done
  printf '%s' "$sig"
}

on_exit() {
  echo
  if [[ -z "$stop_reason" ]]; then
    stop_reason="user interrupt"
  fi
  echo "Simulation stopped at generation $generation ($stop_reason)."
}

main() {
  trap on_exit INT TERM
  setup_theme
  seed_pattern "$PATTERN"
  live_cells=$(count_live_cells)
  seen_signatures["$(grid_signature)"]=0
  print_grid

  while true; do
    if (( MAX_GEN > 0 && generation >= MAX_GEN )); then
      stop_reason="max generations reached"
      break
    fi

    step_generation
    ((++generation))

    if (( live_cells == 0 )); then
      stop_reason="all cells died"
      print_grid
      break
    fi

    local sig
    sig="$(grid_signature)"
    if [[ -n "${seen_signatures[$sig]+x}" ]]; then
      stop_reason="repeated state detected"
      print_grid
      break
    fi
    seen_signatures[$sig]="$generation"

    print_grid
    sleep "$SPEED"
  done

  if [[ -z "$stop_reason" ]]; then
    stop_reason="completed"
  fi
  echo
  echo "Run complete at generation $generation ($stop_reason)."
}

main