# Pigpio Setup Instructions

## Overview

This project has been migrated from `pi_piper` to `pigpio` to support 64-bit Raspberry Pi OS (aarch64). The `pigpio` library is actively maintained and works properly on modern Raspberry Pi systems.

## Installation on Raspberry Pi

### 1. Install pigpio C library

```bash
# Update package list
sudo apt-get update

# Install pigpio library and daemon
sudo apt-get install -y pigpio python3-pigpio

# Enable and start pigpiod daemon
sudo systemctl enable pigpiod
sudo systemctl start pigpiod
```

### 2. Install Ruby gem

The pigpio Ruby gem will be installed automatically when you run:

```bash
bundle install
```

### 3. Verify installation

Check that the pigpiod daemon is running:

```bash
sudo systemctl status pigpiod
```

You should see output indicating the service is active and running.

## Troubleshooting

### "Failed to connect to pigpio" error

If you see this error, the pigpiod daemon is not running. Start it with:

```bash
sudo systemctl start pigpiod
```

### Permission issues

The current user must be in the `gpio` group:

```bash
sudo usermod -a -G gpio $USER
```

Then log out and back in for the group change to take effect.

## Updating native-install.sh

The `scripts/native-install.sh` script should be updated to include pigpio installation. Add these lines:

```bash
# Install pigpio library for GPIO control
print_step "Installing pigpio library"
sudo apt-get install -y pigpio python3-pigpio
sudo systemctl enable pigpiod
sudo systemctl start pigpiod
print_success "pigpio installed and daemon started"
```

## Why pigpio instead of pi_piper?

- **pi_piper** (last updated 2016): Ships with a 32-bit pre-compiled `libbcm2835.so` that doesn't work on 64-bit systems
- **pigpio**: Actively maintained, officially supported on 64-bit Raspberry Pi OS, works with modern kernels

## API Changes

The main API changes in the code:

### Old (pi_piper):
```ruby
require 'pi_piper'
pin = PiPiper::Pin.new(pin: 17, direction: :out)
pin.on   # Set HIGH
pin.off  # Set LOW
```

### New (pigpio):
```ruby
require 'pigpio'
include Pigpio::Constant

pi = Pigpio.new
pi.connect

pin = pi.gpio(17)
pin.mode = PI_OUTPUT
pin.pud = PI_PUD_OFF
pin.write(1)  # Set HIGH
pin.write(0)  # Set LOW

pi.stop  # Cleanup
```

## References

- [pigpio C library documentation](http://abyz.me.uk/rpi/pigpio/)
- [pigpio Ruby gem](https://github.com/nak1114/ruby-extension-pigpio)
- [GitHub issue: pi_piper 64-bit compatibility](https://github.com/jwhitehorn/pi_piper/issues/91)
