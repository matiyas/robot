# Use Debian Trixie ARM64 as base image
FROM debian:trixie

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    RACK_ENV=production \
    RBENV_ROOT=/usr/local/rbenv \
    PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    GEM_HOME=/usr/local/bundle

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    rpicam-apps \
    ffmpeg \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libffi-dev \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Install rbenv and ruby-build
RUN git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv && \
    git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build && \
    /usr/local/rbenv/plugins/ruby-build/install.sh && \
    echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh && \
    chmod +x /etc/profile.d/rbenv.sh

# Copy .ruby-version to determine which Ruby version to install
COPY .ruby-version /tmp/.ruby-version

# Install Ruby via rbenv
RUN RUBY_VERSION=$(cat /tmp/.ruby-version) && \
    rbenv install $RUBY_VERSION && \
    rbenv global $RUBY_VERSION && \
    rbenv rehash && \
    gem install bundler && \
    rbenv rehash

# Create app directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Copy .ruby-version to app directory
COPY .ruby-version ./

# Install Ruby dependencies
# In production, we skip development and test gems
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy application files
COPY . .

# Create directories for logs
RUN mkdir -p /app/logs

# Copy and set up scripts
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-healthcheck.sh

# Expose ports
# 4567 - Sinatra app (development)
# 80 - Sinatra app (production)
# 8081 - Camera stream (rpicam-vid)
EXPOSE 4567 80 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/docker-healthcheck.sh"]

# Set entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Start command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
