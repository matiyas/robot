# Installation Quick Reference Card

Quick reference for installing Robot Tank Control on Raspberry Pi Zero 2W.

---

## 🐳 Docker Installation (3 Commands)

```bash
git clone https://github.com/yourusername/robot.git && cd robot
./scripts/docker-deploy-pi.sh
# Access: http://<PI_IP>
```

**Management:**
```bash
make prod          # Start production
make logs          # View logs
make down          # Stop
make shell         # Shell access
```

---

## 💻 Native Installation (3 Commands)

```bash
git clone https://github.com/yourusername/robot.git && cd robot
./scripts/native-install.sh
sudo reboot
```

**Management:**
```bash
sudo systemctl start robot      # Start
sudo systemctl status robot     # Status
sudo journalctl -u robot -f     # Logs
```

---

## 📦 System Dependencies (Manual Install)

```bash
sudo apt-get update
sudo apt-get install -y \
    ruby ruby-dev build-essential git curl \
    libssl-dev pkg-config motion v4l-utils

sudo gem install bundler
bundle install
```

---

## ✅ Testing

```bash
# Native
./scripts/test-native-setup.sh
curl http://localhost/health

# Docker
make health
docker-compose -f docker-compose.prod.yml ps
```

---

## 🔧 Common Commands

### Docker
```bash
make dev               # Development mode
make prod              # Production mode
make logs              # View logs
make shell             # Interactive shell
make restart           # Restart
make clean             # Clean up
```

### Native
```bash
sudo systemctl start robot      # Start service
sudo systemctl stop robot       # Stop service
sudo systemctl restart robot    # Restart service
sudo systemctl status robot     # Check status
sudo journalctl -u robot -f     # Follow logs
```

---

## 🌐 Access Points

- Web Interface: `http://<PI_IP>`
- API: `http://<PI_IP>/api/v1/`
- Health: `http://<PI_IP>/health`
- Camera: `http://<PI_IP>:8081/stream`

Development mode uses port 4567 instead of 80.

---

## 📚 Full Documentation

- **DOCKER.md** - Complete Docker guide
- **NATIVE_INSTALLATION.md** - Complete native guide
- **README.md** - General documentation

---

## 🆘 Quick Troubleshooting

### Service Won't Start
```bash
# Native
sudo journalctl -u robot -n 50

# Docker
docker-compose logs robot
```

### Camera Not Working
```bash
libcamera-hello --list-cameras
sudo systemctl restart motion
```

### GPIO Not Working
```bash
ls -l /dev/gpiomem
groups | grep gpio
```

### Port Issues
```bash
sudo netstat -tlnp | grep :80
sudo systemctl status robot
```

---

## 📊 Comparison

| Feature | Docker | Native |
|---------|--------|--------|
| Install Time | 5-10 min | 10-15 min |
| Disk Space | 1.5 GB | 500 MB |
| Memory | 60 MB | 50 MB |
| Updates | `make prod` | `git pull && bundle` |
| Best For | Multiple services | Single robot |

---

## 🎯 Choose Docker If...
- Running multiple services
- Want easy updates
- Need reproducible setup
- Deploy across multiple Pis

## 🎯 Choose Native If...
- Dedicated robot controller
- Want max performance
- Prefer simpler setup
- Limited disk space

---

**Quick Links:**
- [Docker Guide](DOCKER.md)
- [Native Guide](NATIVE_INSTALLATION.md)
- [Main README](README.md)
