# Manual pigpio Installation and Fix

Since `pigpio` is not available as a package, follow these steps on your Raspberry Pi:

## Quick Fix (Run on Raspberry Pi)

```bash
cd ~/Workspace/robot

# Pull latest code with updated installation scripts
git pull

# Run the updated QUICK_FIX.sh script
bash QUICK_FIX.sh
```

The script will now:
1. Build pigpio from source
2. Create and start the pigpiod daemon
3. Update Ruby gems
4. Restart your robot services

## Or Manual Installation

If you prefer to do it manually:

### 1. Build and install pigpio

```bash
# Install build tools
sudo apt-get update
sudo apt-get install -y wget unzip build-essential

# Download pigpio source
cd /tmp
wget https://github.com/joan2937/pigpio/archive/master.zip -O pigpio.zip
unzip pigpio.zip
cd pigpio-master

# Compile and install
make
sudo make install
```

### 2. Create systemd service

```bash
sudo tee /etc/systemd/system/pigpiod.service > /dev/null << 'EOF'
[Unit]
Description=Pigpio daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/pigpiod -l
ExecStop=/bin/systemctl kill pigpiod
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

### 3. Start the daemon

```bash
sudo systemctl daemon-reload
sudo systemctl enable pigpiod
sudo systemctl start pigpiod

# Verify it's running
sudo systemctl status pigpiod
```

### 4. Update your robot code

```bash
cd ~/Workspace/robot
git pull
bundle install
```

### 5. Restart robot service

```bash
sudo systemctl daemon-reload
sudo systemctl restart robot
sudo systemctl restart rpicam-stream
```

### 6. Check status

```bash
sudo systemctl status robot
sudo systemctl status pigpiod
```

Your robot should now be working!

## Verify Installation

```bash
# Check pigpiod version
pigpiod -v

# Check if daemon is running
sudo systemctl status pigpiod

# Check robot service
sudo systemctl status robot

# View robot logs
sudo journalctl -u robot -f
```

## Troubleshooting

### Build fails with "command not found"
Make sure you have build-essential installed:
```bash
sudo apt-get install -y build-essential wget unzip
```

### pigpiod fails to start
Check the logs:
```bash
sudo journalctl -u pigpiod -n 50
```

### Robot service still failing
Check Ruby gem installation:
```bash
cd ~/Workspace/robot
bundle check
bundle install
```

Then restart:
```bash
sudo systemctl restart robot
```
