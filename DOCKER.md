# Docker Deployment Guide

This guide explains how to run the Robot Tank Control application using Docker and Docker Compose on Debian Trixie ARM64.

## Prerequisites

- Docker Engine 20.10+ installed on your Raspberry Pi
- Docker Compose 2.0+ installed
- Raspberry Pi Zero 2W or similar ARM64 device
- (Production only) Camera module and GPIO hardware

## Quick Start

### Development Mode (No GPIO Hardware)

For testing and development without GPIO hardware:

```bash
# Build and start the container
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Access the application
# Open browser to http://localhost:4567
```

### Production Mode (Raspberry Pi with GPIO)

For production deployment with GPIO and camera access:

```bash
# Build and start the container
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Access the application
# Open browser to http://<RASPBERRY_PI_IP>
```

## Docker Files Overview

### Dockerfile

The main Dockerfile that:
- Uses Debian Trixie ARM64 as base image
- Installs rbenv (Ruby version manager)
- Installs Ruby via rbenv using the version from `.ruby-version` file
- Installs Motion and system dependencies
- Installs application gems (excluding dev/test in production)
- Sets up the application environment
- Exposes ports 4567 (dev), 80 (prod), and 8081 (camera)

### docker-compose.yml

Default compose file for basic development setup without GPIO access.

### docker-compose.dev.yml

Development-specific configuration:
- Runs in development mode (MockController)
- Mounts code volumes for live editing
- Exposes port 4567
- No privileged mode or device access

### docker-compose.prod.yml

Production-specific configuration:
- Runs in production mode (GpioController)
- Enables privileged mode for GPIO access
- Mounts GPIO and camera devices
- Exposes port 80
- Uses host network mode
- Resource limits for Raspberry Pi

## Building the Image

### Build for ARM64

```bash
# Build using docker-compose
docker-compose -f docker-compose.prod.yml build

# Or build directly
docker build --platform linux/arm64 -t robot-tank:latest .
```

### Build with BuildKit (faster)

```bash
DOCKER_BUILDKIT=1 docker build --platform linux/arm64 -t robot-tank:latest .
```

## Running the Container

### Start Container

```bash
# Development
docker-compose -f docker-compose.dev.yml up -d

# Production
docker-compose -f docker-compose.prod.yml up -d
```

### Stop Container

```bash
# Development
docker-compose -f docker-compose.dev.yml down

# Production
docker-compose -f docker-compose.prod.yml down
```

### Restart Container

```bash
# Development
docker-compose -f docker-compose.dev.yml restart

# Production
docker-compose -f docker-compose.prod.yml restart
```

## Managing the Application

### View Logs

```bash
# Follow logs in real-time
docker-compose -f docker-compose.prod.yml logs -f

# View last 100 lines
docker-compose -f docker-compose.prod.yml logs --tail=100

# View logs for specific service
docker-compose -f docker-compose.prod.yml logs -f robot
```

### Execute Commands in Container

```bash
# Open a shell in the running container
docker-compose -f docker-compose.prod.yml exec robot bash

# Run a Ruby console
docker-compose -f docker-compose.prod.yml exec robot bundle exec pry

# Check application status
docker-compose -f docker-compose.prod.yml exec robot curl http://localhost/health
```

### Check Container Status

```bash
# View running containers
docker-compose -f docker-compose.prod.yml ps

# View resource usage
docker stats robot-tank-prod

# Check health status
docker inspect --format='{{.State.Health.Status}}' robot-tank-prod
```

## Configuration

### Environment Variables

Set environment variables in docker-compose files or create a `.env` file:

```bash
# .env file
RACK_ENV=production
PORT=80
```

### Volume Mounts

Production configuration mounts:
- `./config:/app/config:ro` - Configuration files (read-only)
- `./logs:/app/logs` - Application logs

Development configuration additionally mounts:
- `./app:/app/app` - Application code
- `./lib:/app/lib` - Library code
- `./views:/app/views` - View templates
- `./public:/app/public` - Static assets

### Device Access

Production mode requires these device mounts:
- `/dev/gpiomem` - GPIO memory access
- `/dev/mem` - System memory (for GPIO)
- `/dev/video0` - Camera device

## Networking

### Development Mode

Uses bridge network with port mapping:
- Container port 4567 → Host port 4567
- Container port 8081 → Host port 8081

### Production Mode

Uses host network mode for direct access:
- Application runs on port 80
- Camera stream on port 8081

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker-compose -f docker-compose.prod.yml logs

# Check if ports are already in use
sudo netstat -tulpn | grep -E ':(80|4567|8081)'

# Verify image was built successfully
docker images | grep robot-tank
```

### GPIO Not Working

```bash
# Check if privileged mode is enabled
docker inspect robot-tank-prod | grep Privileged

# Verify devices are mounted
docker inspect robot-tank-prod | grep Devices -A 10

# Check GPIO permissions on host
ls -l /dev/gpiomem
```

### Camera Not Working

```bash
# Verify camera device exists on host
ls -l /dev/video0

# Check Motion logs in container
docker-compose -f docker-compose.prod.yml exec robot tail -f /var/log/motion.log

# Test camera directly
docker-compose -f docker-compose.prod.yml exec robot raspistill -o test.jpg
```

### High Memory Usage

```bash
# Check current memory usage
docker stats robot-tank-prod

# Adjust memory limits in docker-compose file
# Edit deploy.resources.limits.memory

# Restart container with new limits
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

### Permission Errors

```bash
# Ensure log directory exists and is writable
mkdir -p logs
chmod 755 logs

# If using SELinux, adjust context
chcon -R -t svirt_sandbox_file_t logs/
```

## Updating the Application

### Update Code and Rebuild

```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose -f docker-compose.prod.yml up -d --build

# Or rebuild without cache
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d
```

### Update Dependencies

```bash
# Update Gemfile
# Edit Gemfile with new versions

# Rebuild image
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d
```

## Auto-Start on Boot

### Using Docker Restart Policy

The compose files include `restart: unless-stopped` which automatically starts containers on boot.

### Using Systemd (Alternative)

Create `/etc/systemd/system/robot-docker.service`:

```ini
[Unit]
Description=Robot Tank Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/pi/robot
ExecStart=/usr/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Enable the service:

```bash
sudo systemctl enable robot-docker.service
sudo systemctl start robot-docker.service
```

## Performance Optimization

### Reduce Image Size

- Remove unnecessary packages from Dockerfile
- Use multi-stage builds if needed
- Clear apt cache (already done)

### Optimize for Raspberry Pi Zero 2W

Current settings in docker-compose.prod.yml:
- 1 Puma worker (single core optimization)
- Memory limit: 512MB
- CPU limit: 1.0 core

Adjust based on your workload:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.8'      # Leave headroom for system
      memory: 384M     # Reduce if needed
```

## Security Considerations

### Production Deployment

1. Use specific image tags instead of `latest`
2. Enable authentication in `config/settings.yml`
3. Use secrets for sensitive configuration
4. Run container as non-root user (add to Dockerfile)
5. Limit network exposure

### Example: Non-Root User

Add to Dockerfile before ENTRYPOINT:

```dockerfile
RUN groupadd -r robot && useradd -r -g robot robot
RUN chown -R robot:robot /app /var/lib/motion
USER robot
```

## Monitoring

### Health Checks

Container includes automatic health checks:
- Endpoint: `/health`
- Interval: 30 seconds
- Timeout: 3 seconds
- Retries: 3

Check status:

```bash
docker inspect --format='{{json .State.Health}}' robot-tank-prod | jq
```

### Logging

Application logs are available:

```bash
# Puma logs (in production)
docker-compose -f docker-compose.prod.yml exec robot tail -f /app/logs/puma_stdout.log

# Application logs
docker-compose -f docker-compose.prod.yml logs -f robot
```

## Backup and Restore

### Backup Configuration

```bash
# Backup config and data
tar -czf robot-backup-$(date +%Y%m%d).tar.gz config/ logs/
```

### Restore Configuration

```bash
# Extract backup
tar -xzf robot-backup-20240101.tar.gz
```

## Support

For issues with Docker deployment:
1. Check the logs: `docker-compose logs -f`
2. Verify device access: `docker inspect <container>`
3. Review this documentation
4. Check the main README.md for application-specific issues

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Raspberry Pi Docker Guide](https://docs.docker.com/engine/install/debian/)
