# Native Installation - Setup Summary

Complete summary of native installation files and documentation for Raspberry Pi Zero 2W.

---

## 📋 Files Created

### Installation Scripts (4 files)
1. **scripts/native-install.sh** - Complete automated installation
   - Interactive, colored output
   - System verification
   - Dependency installation
   - Service configuration
   - Permission setup
   - ~350 lines

2. **scripts/test-native-setup.sh** - Installation verification
   - Tests all dependencies
   - Checks services
   - Validates configuration
   - ~150 lines

3. **scripts/native-uninstall.sh** - Clean removal
   - Removes services
   - Keeps application code
   - ~80 lines

4. **DEPENDENCIES_REFERENCE.sh** - Dependency reference
   - Shows all required packages
   - Explains each dependency
   - Can be run standalone
   - ~100 lines

### Documentation (3 files)
5. **NATIVE_INSTALLATION.md** - Comprehensive guide
   - Complete installation instructions
   - Manual step-by-step guide
   - Configuration details
   - Troubleshooting section
   - Performance optimization
   - ~600 lines

6. **INSTALLATION_QUICK_REFERENCE.md** - Quick reference card
   - 3-command installations
   - Common commands
   - Comparison table
   - 1-page reference

7. **NATIVE_SETUP_SUMMARY.md** - This file
   - Overview of all files
   - Quick start guide
   - Testing procedures

### Updated Files (2 files)
8. **scripts/setup.sh** - Enhanced original script
   - Added libssl-dev dependency
   - Improved for compatibility

9. **README.md** - Updated with native installation
   - Added Docker vs Native comparison
   - Installation options clearly presented
   - Quick reference section
   - Links to detailed guides

---

## 🚀 Quick Start (3 Commands)

```bash
# 1. Clone and enter directory
git clone https://github.com/yourusername/robot.git && cd robot

# 2. Run installation
./scripts/native-install.sh

# 3. Reboot
sudo reboot
```

After reboot, the robot service starts automatically!

---

## 📦 What Gets Installed

### System Packages
```
ruby            - Ruby interpreter (v3.1+)
ruby-dev        - Ruby development headers
build-essential - GCC, G++, make, libc-dev
git             - Version control
curl            - HTTP client
libssl-dev      - OpenSSL development headers ⭐ Required for gem compilation
pkg-config      - Package configuration tool
motion          - Camera streaming server
v4l-utils       - Video4Linux utilities
```

### Ruby Gems (Production)
```
puma            - High-performance web server
sinatra         - Lightweight web framework
sinatra-contrib - Sinatra extensions
pi_piper        - GPIO control library (includes eventmachine)
```

### Services Configured
```
robot.service   - Main application service
motion.service  - Camera streaming service
```

### User Groups
```
video           - Camera access
gpio            - GPIO pin access
```

---

## 📖 Documentation Hierarchy

```
README.md
├── Installation Options
│   ├── Docker → DOCKER.md (comprehensive)
│   └── Native → NATIVE_INSTALLATION.md (comprehensive)
│
├── Quick Reference → INSTALLATION_QUICK_REFERENCE.md
│
├── Native Setup → NATIVE_SETUP_SUMMARY.md (this file)
│
└── Dependencies → DEPENDENCIES_REFERENCE.sh
```

---

## 🎯 Installation Methods

### Method 1: Automated (Recommended)
```bash
./scripts/native-install.sh
```
- Interactive prompts
- Colored output
- Error checking
- Service setup
- Reboot prompt
- **Time: 10-15 minutes**

### Method 2: Quick (Legacy)
```bash
./scripts/setup.sh
```
- Original setup script
- Less interactive
- Still fully functional
- **Time: 10-15 minutes**

### Method 3: Manual
Follow step-by-step in `NATIVE_INSTALLATION.md`
- Full control
- Learn each step
- Good for customization
- **Time: 15-20 minutes**

### Method 4: Dependencies Only
```bash
./DEPENDENCIES_REFERENCE.sh
```
- Install packages and gems only
- No service configuration
- For development setups
- **Time: 5-10 minutes**

---

## ✅ Testing Your Installation

### Automated Test
```bash
./scripts/test-native-setup.sh
```

Checks:
- ✓ System commands installed
- ✓ Build tools present
- ✓ Libraries available
- ✓ Ruby gems installed
- ✓ Services configured
- ✓ User permissions set
- ✓ Camera device detected
- ✓ GPIO device present
- ✓ Network configured

### Manual Tests

#### 1. Test Service
```bash
sudo systemctl status robot
sudo journalctl -u robot -f
```

#### 2. Test API
```bash
curl http://localhost/health
curl http://localhost/api/v1/status
```

#### 3. Test Web Interface
```bash
# Open browser
http://<PI_IP_ADDRESS>
```

#### 4. Test Camera (if configured)
```bash
libcamera-hello --list-cameras
sudo systemctl status motion
curl http://localhost:8081
```

#### 5. Test GPIO
```bash
ls -l /dev/gpiomem
groups | grep gpio
```

---

## 🔧 Common Commands

### Service Management
```bash
sudo systemctl start robot       # Start
sudo systemctl stop robot        # Stop
sudo systemctl restart robot     # Restart
sudo systemctl status robot      # Status
sudo systemctl enable robot      # Enable auto-start
sudo systemctl disable robot     # Disable auto-start
```

### Viewing Logs
```bash
sudo journalctl -u robot -f      # Follow robot logs
sudo journalctl -u motion -f     # Follow motion logs
sudo journalctl -u robot -n 50   # Last 50 lines
tail -f ~/robot/logs/*.log       # Application logs
```

### Manual Start (Testing)
```bash
cd ~/robot
RACK_ENV=production bundle exec puma -C config/puma.rb
```

### Development Mode
```bash
cd ~/robot
bundle exec ruby app/robot_app.rb
# Access at http://localhost:4567
```

---

## 🆘 Troubleshooting

### Quick Diagnosis
```bash
# Run test script
./scripts/test-native-setup.sh

# Check service
sudo systemctl status robot

# View recent logs
sudo journalctl -u robot -n 50
```

### Common Issues

#### Service Won't Start
```bash
# Check logs for errors
sudo journalctl -u robot -xe

# Test manually
cd ~/robot
bundle exec ruby app/robot_app.rb
```

#### Gems Won't Install
```bash
# Ensure dev headers present
sudo apt-get install -y ruby-dev build-essential libssl-dev

# Clear cache and retry
bundle clean --force
bundle install
```

#### Permission Errors
```bash
# Add to groups
sudo usermod -a -G video,gpio $USER

# Log out and back in (or reboot)
sudo reboot
```

#### Port 80 Denied
```bash
# Use systemd service (handles privileges)
sudo systemctl start robot

# Or change port to 4567 in config/settings.yml
```

### Full Troubleshooting Guide
See `NATIVE_INSTALLATION.md` - Troubleshooting section

---

## 📊 Resource Usage (Pi Zero 2W)

### System Requirements
- **RAM**: ~50 MB application + ~30 MB Motion
- **Disk**: ~500 MB (Ruby + gems + dependencies)
- **CPU**: 5-10% idle, 20-40% active

### Performance Tips
See `NATIVE_INSTALLATION.md` - Performance Optimization section

---

## 🔄 Updating

```bash
# Stop service
sudo systemctl stop robot

# Update code
cd ~/robot
git pull

# Update gems
bundle install

# Restart
sudo systemctl start robot
```

---

## 🗑️ Uninstallation

### Remove Services Only
```bash
./scripts/native-uninstall.sh
```

### Complete Removal
```bash
# Stop services
sudo systemctl stop robot motion
sudo systemctl disable robot motion

# Remove service files
sudo rm /etc/systemd/system/robot.service
sudo systemctl daemon-reload

# Remove application
rm -rf ~/robot

# Optional: Remove packages
sudo apt-get remove motion
sudo apt-get autoremove
```

---

## 📂 Directory Structure

```
~/robot/
├── app/                      # Application code
├── config/                   # Configuration files
├── lib/                      # Libraries
├── public/                   # Web assets
├── views/                    # HTML templates
├── scripts/
│   ├── native-install.sh     # ⭐ Main installer
│   ├── test-native-setup.sh  # ⭐ Test script
│   ├── native-uninstall.sh   # ⭐ Uninstaller
│   ├── setup.sh              # Legacy installer
│   ├── motion.conf           # Camera config
│   └── robot.service         # Systemd service
├── logs/                     # Application logs
├── NATIVE_INSTALLATION.md    # ⭐ Detailed guide
├── INSTALLATION_QUICK_REFERENCE.md  # ⭐ Quick ref
├── NATIVE_SETUP_SUMMARY.md   # ⭐ This file
├── DEPENDENCIES_REFERENCE.sh # ⭐ Dependency script
├── README.md                 # Main documentation
└── Gemfile                   # Ruby dependencies
```

---

## 🎓 Learning Path

### Beginner
1. Read `INSTALLATION_QUICK_REFERENCE.md`
2. Run `./scripts/native-install.sh`
3. Test with `./scripts/test-native-setup.sh`
4. Access web interface

### Intermediate
1. Read `NATIVE_INSTALLATION.md` (full guide)
2. Understand each installation step
3. Configure camera and GPIO
4. Customize settings

### Advanced
1. Review `DEPENDENCIES_REFERENCE.sh`
2. Manual installation
3. Performance tuning
4. Custom configurations
5. Integration with other services

---

## 🔗 Quick Links

- **Main README**: [README.md](README.md)
- **Docker Guide**: [DOCKER.md](DOCKER.md)
- **Native Guide**: [NATIVE_INSTALLATION.md](NATIVE_INSTALLATION.md)
- **Quick Reference**: [INSTALLATION_QUICK_REFERENCE.md](INSTALLATION_QUICK_REFERENCE.md)
- **Docker Test Report**: [DOCKER_TEST_REPORT.md](DOCKER_TEST_REPORT.md)

---

## 🎯 Key Features of Native Installation

### Advantages
✅ Direct system integration
✅ Lower resource usage (~50 MB RAM)
✅ Faster startup (< 3 seconds)
✅ Easier debugging
✅ Simple updates (git pull)
✅ No container overhead
✅ Direct GPIO access
✅ Smaller disk footprint (500 MB)

### When to Choose Native
- Running dedicated robot controller
- Want maximum performance
- Prefer simpler architecture
- Limited resources (disk/memory)
- Don't need multiple services
- Want direct hardware access

---

## 📝 Notes

### Compatibility
- **Tested on**: Raspberry Pi OS (64-bit) Bookworm
- **Architecture**: ARM64 (aarch64)
- **Ruby version**: 3.1+
- **Debian version**: 12+ (Bookworm)

### Security
- Service runs as your user (not root)
- GPIO/video group membership required
- Port 80 handled by systemd (no sudo needed)
- No unnecessary elevated privileges

### Maintenance
- Auto-updates: Not configured (manual git pull)
- Auto-start: Enabled by default
- Log rotation: Handled by journald
- Backups: Git-based (commit before changes)

---

## 🎉 Success Checklist

After installation, verify:

- [ ] `./scripts/test-native-setup.sh` passes
- [ ] `sudo systemctl status robot` shows "active (running)"
- [ ] `curl http://localhost/health` returns JSON
- [ ] Web interface accessible at `http://<PI_IP>`
- [ ] Camera stream working (if configured)
- [ ] GPIO device accessible: `ls /dev/gpiomem`
- [ ] Auto-start enabled: `systemctl is-enabled robot`
- [ ] No errors in logs: `sudo journalctl -u robot -n 20`

---

## 📞 Getting Help

1. **Run test script**: `./scripts/test-native-setup.sh`
2. **Check logs**: `sudo journalctl -u robot -f`
3. **Read troubleshooting**: `NATIVE_INSTALLATION.md`
4. **Compare with Docker**: See if issue is environment-specific
5. **Open issue**: Provide output from test script and logs

---

**Your Robot Tank is ready! 🤖**

Start with: `sudo systemctl start robot`
Access at: `http://<YOUR_PI_IP>`
