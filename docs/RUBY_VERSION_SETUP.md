# Ruby Version Management Setup

This document describes the Ruby version management setup for the Robot Tank Control project.

## Overview

The project now uses **rbenv** to manage Ruby versions consistently across all environments:
- Docker containers
- Native installations on Raspberry Pi
- Local development machines

## Ruby Version

The project uses **Ruby 3.2.2** as specified in the `.ruby-version` file.

## Why rbenv?

1. **Version Consistency**: Ensures the exact same Ruby version is used across all environments
2. **No System Ruby**: Avoids conflicts with system Ruby packages
3. **Easy Updates**: Simple to change Ruby versions by updating `.ruby-version`
4. **Development Standard**: Industry standard for Ruby version management
5. **Reproducible Builds**: Docker and native installations use identical Ruby version

## Files Added/Modified

### New Files
- `.ruby-version` - Specifies Ruby 3.2.2

### Modified Files
- `Gemfile` - Added Ruby version requirement: `ruby '~> 3.2.2'`
- `Gemfile.lock` - Updated with Ruby version: `ruby 3.2.2p53`
- `Dockerfile` - Replaced system Ruby with rbenv installation
- `scripts/native-install.sh` - Updated to install rbenv and Ruby
- `scripts/setup.sh` - Updated to install rbenv and Ruby
- `scripts/robot.service` - Updated PATH to include rbenv shims
- `README.md` - Updated installation instructions
- `NATIVE_INSTALLATION.md` - Added rbenv installation steps
- `DOCKER.md` - Updated Dockerfile description

## Docker Setup

The Dockerfile now:
1. Installs rbenv and ruby-build from GitHub
2. Copies `.ruby-version` to determine which Ruby to install
3. Installs the specified Ruby version via `rbenv install`
4. Sets up environment variables for rbenv

```dockerfile
ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH
```

## Native Installation Setup

The native installation scripts now:
1. Install build dependencies (libssl-dev, libreadline-dev, zlib1g-dev)
2. Clone rbenv to `~/.rbenv`
3. Clone ruby-build plugin
4. Install Ruby from `.ruby-version` file
5. Configure shell to initialize rbenv

The systemd service file includes rbenv in PATH:
```
Environment="PATH=/home/pi/.rbenv/shims:/home/pi/.rbenv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="RBENV_ROOT=/home/pi/.rbenv"
```

## Verifying Ruby Version

### Check Active Ruby Version
```bash
ruby --version
# Should output: ruby 3.2.2p53 (2023-03-30 revision e51014f9c0)
```

### Check rbenv Version
```bash
rbenv version
# Should output: 3.2.2 (set by /path/to/.ruby-version)
```

### Check Gemfile Requirements
```bash
bundle platform
# Should show: ruby 3.2.2p53
```

## Changing Ruby Version

To change the Ruby version for the entire project:

1. Update `.ruby-version` file with new version (e.g., `3.3.0`)
2. Update `Gemfile` if needed: `ruby '~> 3.3.0'`
3. Install new version:
   - **Docker**: Rebuild the image: `docker-compose build`
   - **Native**: Run `rbenv install $(cat .ruby-version)`
4. Update Gemfile.lock: `bundle install`
5. Test thoroughly before deploying

## Troubleshooting

### rbenv not found
```bash
# Make sure rbenv is in PATH
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Add to ~/.bashrc for persistence
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

### Wrong Ruby version active
```bash
# Check what rbenv sees
rbenv versions

# Set global version
rbenv global 3.2.2

# Rehash shims
rbenv rehash
```

### Ruby compilation fails on Pi Zero 2W
Ruby compilation can take 10-20 minutes on Pi Zero 2W. If it fails:

```bash
# Make sure all build dependencies are installed
sudo apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev libffi-dev libyaml-dev

# Try installing again
rbenv install 3.2.2
```

### Docker build fails
```bash
# Make sure .ruby-version is copied to the image
# Check Dockerfile includes:
COPY .ruby-version /tmp/.ruby-version
COPY .ruby-version ./
```

## Benefits Achieved

1. ✅ **Consistency**: Same Ruby 3.2.2 in Docker and native
2. ✅ **Reproducibility**: `.ruby-version` defines exact version
3. ✅ **Portability**: Works on macOS (development) and Linux (Pi)
4. ✅ **Maintainability**: Easy to update Ruby version
5. ✅ **Best Practice**: Industry-standard approach
6. ✅ **No System Conflicts**: rbenv isolates from system Ruby

## Installation Times

- **Docker Build**: ~5-7 minutes (Ruby compilation included)
- **Native Install**: ~10-20 minutes on Pi Zero 2W (Ruby compilation)
- **Local Dev**: ~3-5 minutes on modern laptop (Ruby compilation)

## References

- rbenv: https://github.com/rbenv/rbenv
- ruby-build: https://github.com/rbenv/ruby-build
- Ruby versions: https://www.ruby-lang.org/en/downloads/releases/
