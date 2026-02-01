# GPIO Pin Monitoring Guide

This guide explains how to monitor GPIO pin states in real-time to debug and verify motor control operations.

## Quick Start

### Option 1: Terminal Monitor (Recommended)

Run directly on Raspberry Pi:
```bash
ssh rpi@192.168.1.109
cd ~/Workspace/robot
./scripts/gpio-monitor.sh
```

This provides a colorful, auto-refreshing terminal display showing:
- All motor GPIO pin states (HIGH/LOW)
- Motor states (COAST, FORWARD, BACKWARD, BRAKE)
- System state (what the robot is doing)
- Real-time updates every 0.2 seconds

**Controls:**
- Press `Ctrl+C` to exit
- Change refresh rate: `./scripts/gpio-monitor.sh 0.5` (updates every 0.5 seconds)

### Option 2: Web-Based Monitor

Start the web monitor:
```bash
ssh rpi@192.168.1.109
cd ~/Workspace/robot
ruby scripts/gpio-monitor-web.rb
```

Then open in your browser:
```
http://192.168.1.109:8082
```

Features:
- Beautiful responsive web interface
- Color-coded pin states (green=HIGH, red=LOW)
- Works on desktop, tablet, and mobile
- Auto-refreshes every 0.2 seconds
- No installation required (just Ruby)

### Option 3: Command-Line One-Liners

**Watch a single pin:**
```bash
watch -n 0.5 'ssh rpi@192.168.1.109 "pigs r 17"'
```

**Watch all motor pins:**
```bash
watch -n 0.5 'ssh rpi@192.168.1.109 "echo Left: \$(pigs r 17) \$(pigs r 18) | Right: \$(pigs r 22) \$(pigs r 23) | Turret: \$(pigs r 27) \$(pigs r 24)"'
```

**Simple loop from Pi:**
```bash
ssh rpi@192.168.1.109
while true; do echo "GPIO17=$(pigs r 17) GPIO22=$(pigs r 22)"; sleep 0.5; done
```

## GPIO Pin Reference

### Motor Pin Mapping

| Motor | Function | IN1 Pin | IN2 Pin | Notes |
|-------|----------|---------|---------|-------|
| **Left Wheel** | Drive | GPIO 17 | GPIO 18 | Tank left side |
| **Right Wheel** | Drive | GPIO 22 | GPIO 23 | Tank right side |
| **Turret** | Camera rotation | GPIO 27 | GPIO 24 | Pan left/right |

### Motor Truth Table (DRV8833)

| IN1 | IN2 | Motor State | Description |
|-----|-----|-------------|-------------|
| LOW | LOW | **COAST** | Motor off (freewheeling) |
| HIGH | LOW | **FORWARD** | Motor rotates forward/CW |
| LOW | HIGH | **BACKWARD** | Motor rotates backward/CCW |
| HIGH | HIGH | **BRAKE** | Active braking (not used) |

## Understanding Motor States

### Wheel Motors

**Forward Movement:**
- Left: IN1=HIGH, IN2=LOW
- Right: IN1=HIGH, IN2=LOW
- Both wheels rotate forward

**Backward Movement:**
- Left: IN1=LOW, IN2=HIGH
- Right: IN1=LOW, IN2=HIGH
- Both wheels rotate backward

**Left Turn (Tank Steering):**
- Left: IN1=LOW, IN2=HIGH (backward)
- Right: IN1=HIGH, IN2=LOW (forward)
- Robot pivots left

**Right Turn (Tank Steering):**
- Left: IN1=HIGH, IN2=LOW (forward)
- Right: IN1=LOW, IN2=HIGH (backward)
- Robot pivots right

**Stopped:**
- All pins: LOW
- Coast mode (freewheeling)

### Turret Motor

**Rotate Left:**
- IN1=LOW, IN2=HIGH

**Rotate Right:**
- IN1=HIGH, IN2=LOW

**Stopped:**
- IN1=LOW, IN2=LOW

## Using the Terminal Monitor

### Basic Usage

```bash
# Default refresh rate (0.2 seconds)
./scripts/gpio-monitor.sh

# Custom refresh rate (0.5 seconds)
./scripts/gpio-monitor.sh 0.5

# Very fast refresh (0.1 seconds)
./scripts/gpio-monitor.sh 0.1
```

### Example Output

```
═══════════════════════════════════════════════════════════
           GPIO Pin Monitor - Robot Tank Control
═══════════════════════════════════════════════════════════

Press Ctrl+C to exit

┌─────────────────────────────────────────────────────────┐
│ LEFT MOTOR (Wheel)                                      │
├─────────────────────────────────────────────────────────┤
│  GPIO 17 (IN1): HIGH                                    │
│  GPIO 18 (IN2): LOW                                     │
│  State:        FORWARD                                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ RIGHT MOTOR (Wheel)                                     │
├─────────────────────────────────────────────────────────┤
│  GPIO 22 (IN1): HIGH                                    │
│  GPIO 23 (IN2): LOW                                     │
│  State:        FORWARD                                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ TURRET MOTOR (Camera)                                   │
├─────────────────────────────────────────────────────────┤
│  GPIO 27 (IN1): LOW                                     │
│  GPIO 24 (IN2): LOW                                     │
│  State:        COAST                                    │
└─────────────────────────────────────────────────────────┘

System State: Moving FORWARD

Last update: 2026-02-01 01:30:45.123  (refresh: 0.2s)
```

### Color Legend

- **GREEN (HIGH)**: Pin is outputting 3.3V (active)
- **RED (LOW)**: Pin is at 0V (inactive)
- **BLUE (COAST)**: Motor is stopped
- **GREEN (FORWARD)**: Motor moving forward
- **YELLOW (BACKWARD)**: Motor moving backward
- **RED (BRAKE)**: Motor braking (should not occur)

## Using the Web Monitor

### Starting the Server

```bash
# SSH into Raspberry Pi
ssh rpi@192.168.1.109

# Navigate to project directory
cd ~/Workspace/robot

# Start web monitor
ruby scripts/gpio-monitor-web.rb
```

Server will start on port 8082:
```
== Sinatra (v3.2.0) has taken the stage on 8082 for development
```

### Accessing the Interface

Open in any web browser:
```
http://192.168.1.109:8082
```

Or from the Raspberry Pi itself:
```
http://localhost:8082
```

### Features

- **Real-time updates**: Refreshes 5 times per second
- **Responsive design**: Works on phone, tablet, desktop
- **Visual feedback**: Color-coded states with animations
- **Live indicator**: Pulse animation shows active monitoring
- **Error handling**: Displays connection errors clearly

### Running as Background Service

Create a systemd service for persistent monitoring:

```bash
sudo nano /etc/systemd/system/gpio-monitor.service
```

Add:
```ini
[Unit]
Description=GPIO Monitor Web Interface
After=network.target pigpiod.service

[Service]
Type=simple
User=rpi
WorkingDirectory=/home/rpi/Workspace/robot
ExecStart=/home/rpi/.rbenv/shims/ruby scripts/gpio-monitor-web.rb
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable gpio-monitor
sudo systemctl start gpio-monitor
```

## Direct GPIO Commands

### Reading Pins

**Single pin:**
```bash
pigs r 17
# Output: 0 (LOW) or 1 (HIGH)
```

**Multiple pins:**
```bash
pigs r 17 r 18 r 22 r 23
# Output: 0 1 1 0
```

### Writing Pins (Testing Only)

⚠️ **Warning**: Manual GPIO writes can interfere with the robot service.

```bash
# Set GPIO 17 to HIGH
pigs w 17 1

# Set GPIO 17 to LOW
pigs w 17 0
```

### Batch Reading

```bash
# All motor pins in one command
pigs r 17 r 18 r 22 r 23 r 27 r 24
```

## Debugging Scenarios

### Scenario 1: Robot Not Moving

**Symptom**: Send forward command but robot doesn't move.

**Debug Steps:**
1. Start GPIO monitor: `./scripts/gpio-monitor.sh`
2. Send forward command via API
3. Check if GPIO pins change to HIGH
4. If pins stay LOW: software issue (robot service)
5. If pins go HIGH but no movement: hardware issue (motor driver, wiring, power)

### Scenario 2: One Motor Not Working

**Symptom**: Left wheel works, right wheel doesn't.

**Debug Steps:**
1. Monitor GPIO during movement
2. If both wheels show correct GPIO states:
   - Check motor driver wiring
   - Check motor power supply
   - Test motor directly with power
3. If one motor's GPIO stays LOW:
   - Check code in `gpio_controller.rb`
   - Verify pin configuration in `gpio_pins.yml`

### Scenario 3: Motors Don't Stop

**Symptom**: Motors continue after duration expires.

**Debug Steps:**
1. Monitor GPIO during and after movement
2. Check if pins return to LOW after timeout
3. If pins stay HIGH:
   - Check auto-stop logic in `gpio_controller.rb`
   - Verify thread management
4. If pins go LOW but motors continue:
   - Hardware issue (motor driver stuck)
   - Send manual stop: `pigs w 17 0 w 18 0 w 22 0 w 23 0`

### Scenario 4: Incorrect Direction

**Symptom**: Forward command makes robot go backward.

**Debug Steps:**
1. Monitor GPIO during forward command
2. Check which pins are HIGH/LOW
3. Compare to expected truth table
4. If GPIO correct but direction wrong:
   - Motor wiring reversed (swap motor wires)
5. If GPIO incorrect:
   - Fix `set_motor_direction` in `gpio_controller.rb`
   - Verify pin mapping in `gpio_pins.yml`

## Troubleshooting

### "pigs: command not found"

**Solution:**
```bash
# Install pigpio
sudo apt-get install pigpio

# Start daemon
sudo systemctl start pigpiod

# Enable on boot
sudo systemctl enable pigpiod
```

### "Can't connect to pigpio daemon"

**Solution:**
```bash
# Check if pigpiod is running
sudo systemctl status pigpiod

# Start if not running
sudo systemctl start pigpiod

# Check if port 8888 is accessible
sudo netstat -tulpn | grep 8888
```

### Monitor Shows All "?" States

**Causes:**
1. pigpiod not running
2. Permission issues
3. GPIO pins not initialized

**Solution:**
```bash
# Restart pigpiod
sudo systemctl restart pigpiod

# Check robot service
sudo systemctl status robot

# Verify pin permissions
sudo usermod -a -G gpio $USER
```

### Web Monitor Won't Start

**Error**: "Address already in use"

**Solution:**
```bash
# Check what's using port 8082
sudo lsof -i :8082

# Kill existing process
sudo kill <PID>

# Or use different port
ruby scripts/gpio-monitor-web.rb -p 8083
```

## Advanced Monitoring

### Logging Pin States

**Save to file:**
```bash
while true; do
  echo "$(date '+%H:%M:%S.%3N') GPIO17=$(pigs r 17) GPIO22=$(pigs r 22)" >> gpio_log.txt
  sleep 0.1
done
```

**Analyze log:**
```bash
# Count HIGH states
grep "GPIO17=1" gpio_log.txt | wc -l

# Find duration of movement
grep -A 1 "GPIO17=1" gpio_log.txt | head -1
grep "GPIO17=0" gpio_log.txt | tail -1
```

### CSV Export

```bash
# Create CSV header
echo "timestamp,left_in1,left_in2,right_in1,right_in2,turret_in1,turret_in2" > gpio_data.csv

# Log data
while true; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
  gpio17=$(pigs r 17)
  gpio18=$(pigs r 18)
  gpio22=$(pigs r 22)
  gpio23=$(pigs r 23)
  gpio27=$(pigs r 27)
  gpio24=$(pigs r 24)
  echo "$timestamp,$gpio17,$gpio18,$gpio22,$gpio23,$gpio27,$gpio24" >> gpio_data.csv
  sleep 0.1
done
```

**Analyze with:**
- Python pandas
- Excel/LibreOffice Calc
- gnuplot

### Performance Testing

**Measure response time:**
```bash
time curl -X POST http://localhost:4567/api/v1/move \
  -H "Content-Type: application/json" \
  -d '{"direction":"forward","duration":500}'
```

**Measure GPIO switching speed:**
```bash
# Measure time for pin to go HIGH
start=$(date +%s.%N)
while [[ $(pigs r 17) == "0" ]]; do sleep 0.01; done
end=$(date +%s.%N)
echo "Response time: $(echo "$end - $start" | bc) seconds"
```

## Integration with Testing

### Automated Test Script

```bash
#!/bin/bash
# Test all motor directions and verify GPIO

test_direction() {
  local direction=$1
  echo "Testing $direction..."

  # Send command
  curl -X POST http://localhost:4567/api/v1/move \
    -H "Content-Type: application/json" \
    -d "{\"direction\":\"$direction\",\"duration\":1000}" &

  # Wait for GPIO to change
  sleep 0.3

  # Check GPIO states
  gpio17=$(pigs r 17)
  gpio22=$(pigs r 22)

  echo "  GPIO states: 17=$gpio17, 22=$gpio22"

  # Wait for movement to complete
  wait
  sleep 1.5
}

# Run tests
test_direction "forward"
test_direction "backward"
test_direction "left"
test_direction "right"

echo "All tests complete"
```

## References

- [pigpio Documentation](http://abyz.me.uk/rpi/pigpio/)
- [DRV8833 Datasheet](https://www.ti.com/product/DRV8833)
- [GPIO Pin Layout](https://pinout.xyz/)
- [VIDEO_STREAMING.md](VIDEO_STREAMING.md) - Camera streaming architecture
- [config/gpio_pins.yml](config/gpio_pins.yml) - Pin configuration

## Additional Tools

### Raspberry Pi GPIO CLI

If you have `gpio` command installed (WiringPi):
```bash
# Read all pins
gpio readall

# Read specific pin (BCM numbering)
gpio -g read 17
```

### Python One-Liner

```bash
python3 -c "import RPi.GPIO as GPIO; GPIO.setmode(GPIO.BCM); GPIO.setup(17, GPIO.IN); print(GPIO.input(17))"
```

### C Program for High-Speed Monitoring

For sub-millisecond monitoring, use pigpio C API:
```c
#include <stdio.h>
#include <pigpio.h>

int main() {
    if (gpioInitialise() < 0) return 1;

    while (1) {
        printf("GPIO 17: %d\n", gpioRead(17));
        gpioDelay(100000); // 0.1 second
    }

    gpioTerminate();
}
```

Compile and run:
```bash
gcc -o gpio-monitor gpio-monitor.c -lpigpio
./gpio-monitor
```
