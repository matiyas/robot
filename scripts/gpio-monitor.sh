#!/bin/bash
# GPIO Pin Monitor - Real-time monitoring of motor control pins
# Usage: ./gpio-monitor.sh [update_interval]
# Default update interval: 0.2 seconds

# Configuration
UPDATE_INTERVAL="${1:-0.2}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Motor pin definitions (from config/gpio_pins.yml)
LEFT_IN1=17
LEFT_IN2=18
RIGHT_IN1=22
RIGHT_IN2=23
TURRET_IN1=27
TURRET_IN2=24

# Function to read pin state
read_pin() {
  pigs r "$1" 2>/dev/null || echo "?"
}

# Function to get motor state description
get_motor_state() {
  local in1=$1
  local in2=$2

  if [[ "$in1" == "0" && "$in2" == "0" ]]; then
    echo "COAST"
  elif [[ "$in1" == "1" && "$in2" == "0" ]]; then
    echo "FORWARD"
  elif [[ "$in1" == "0" && "$in2" == "1" ]]; then
    echo "BACKWARD"
  elif [[ "$in1" == "1" && "$in2" == "1" ]]; then
    echo "BRAKE"
  else
    echo "UNKNOWN"
  fi
}

# Function to get color for pin state
pin_color() {
  if [[ "$1" == "1" ]]; then
    echo -e "${GREEN}HIGH${NC}"
  else
    echo -e "${RED}LOW${NC}"
  fi
}

# Function to get color for motor state
state_color() {
  case "$1" in
    COAST)    echo -e "${BLUE}$1${NC}" ;;
    FORWARD)  echo -e "${GREEN}$1${NC}" ;;
    BACKWARD) echo -e "${YELLOW}$1${NC}" ;;
    BRAKE)    echo -e "${RED}$1${NC}" ;;
    *)        echo "$1" ;;
  esac
}

# Check if running on Raspberry Pi
if ! command -v pigs &> /dev/null; then
  echo "Error: pigs command not found. This script must run on Raspberry Pi with pigpiod installed."
  echo ""
  echo "To monitor remotely from your computer, use:"
  echo "  ssh rpi@192.168.1.109 './Workspace/robot/scripts/gpio-monitor.sh'"
  exit 1
fi

# Check if pigpiod is running
if ! pigs t &> /dev/null; then
  echo "Error: pigpiod is not running."
  echo "Start it with: sudo systemctl start pigpiod"
  exit 1
fi

# Main monitoring loop
clear
echo "═══════════════════════════════════════════════════════════"
echo "           GPIO Pin Monitor - Robot Tank Control           "
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Press Ctrl+C to exit"
echo ""

while true; do
  # Read all pin states
  left_in1=$(read_pin $LEFT_IN1)
  left_in2=$(read_pin $LEFT_IN2)
  right_in1=$(read_pin $RIGHT_IN1)
  right_in2=$(read_pin $RIGHT_IN2)
  turret_in1=$(read_pin $TURRET_IN1)
  turret_in2=$(read_pin $TURRET_IN2)

  # Calculate motor states
  left_state=$(get_motor_state "$left_in1" "$left_in2")
  right_state=$(get_motor_state "$right_in1" "$right_in2")
  turret_state=$(get_motor_state "$turret_in1" "$turret_in2")

  # Move cursor to line 6 (preserve header)
  tput cup 5 0

  # Display motor states
  echo "┌─────────────────────────────────────────────────────────┐"
  echo "│ LEFT MOTOR (Wheel)                                      │"
  echo "├─────────────────────────────────────────────────────────┤"
  printf "│  GPIO %-2d (IN1): %-33s               │\n" "$LEFT_IN1" "$(pin_color "$left_in1")"
  printf "│  GPIO %-2d (IN2): %-33s               │\n" "$LEFT_IN2" "$(pin_color "$left_in2")"
  printf "│  State:        %-33s               │\n" "$(state_color "$left_state")"
  echo "└─────────────────────────────────────────────────────────┘"
  echo ""

  echo "┌─────────────────────────────────────────────────────────┐"
  echo "│ RIGHT MOTOR (Wheel)                                     │"
  echo "├─────────────────────────────────────────────────────────┤"
  printf "│  GPIO %-2d (IN1): %-33s               │\n" "$RIGHT_IN1" "$(pin_color "$right_in1")"
  printf "│  GPIO %-2d (IN2): %-33s               │\n" "$RIGHT_IN2" "$(pin_color "$right_in2")"
  printf "│  State:        %-33s               │\n" "$(state_color "$right_state")"
  echo "└─────────────────────────────────────────────────────────┘"
  echo ""

  echo "┌─────────────────────────────────────────────────────────┐"
  echo "│ TURRET MOTOR (Camera)                                   │"
  echo "├─────────────────────────────────────────────────────────┤"
  printf "│  GPIO %-2d (IN1): %-33s               │\n" "$TURRET_IN1" "$(pin_color "$turret_in1")"
  printf "│  GPIO %-2d (IN2): %-33s               │\n" "$TURRET_IN2" "$(pin_color "$turret_in2")"
  printf "│  State:        %-33s               │\n" "$(state_color "$turret_state")"
  echo "└─────────────────────────────────────────────────────────┘"
  echo ""

  # Show overall system state
  if [[ "$left_state" == "COAST" && "$right_state" == "COAST" && "$turret_state" == "COAST" ]]; then
    echo "System State: $(state_color 'COAST') - All motors stopped"
  elif [[ "$left_state" == "$right_state" && "$turret_state" == "COAST" ]]; then
    echo "System State: Moving $(state_color "$left_state")"
  elif [[ "$left_state" == "BACKWARD" && "$right_state" == "FORWARD" ]]; then
    echo "System State: Turning LEFT (tank steering)"
  elif [[ "$left_state" == "FORWARD" && "$right_state" == "BACKWARD" ]]; then
    echo "System State: Turning RIGHT (tank steering)"
  elif [[ "$turret_state" != "COAST" ]]; then
    if [[ "$turret_in1" == "1" ]]; then
      echo "System State: Turret rotating RIGHT"
    else
      echo "System State: Turret rotating LEFT"
    fi
  else
    echo "System State: MIXED - Multiple operations"
  fi

  echo ""
  echo "Last update: $(date '+%Y-%m-%d %H:%M:%S.%3N')  (refresh: ${UPDATE_INTERVAL}s)"

  sleep "$UPDATE_INTERVAL"
done
