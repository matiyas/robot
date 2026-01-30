.PHONY: help build build-dev build-prod up down restart logs shell test clean dev prod status health

# Default target
help:
	@echo "Robot Tank Docker Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make build      - Build Docker image"
	@echo "  make build-dev  - Build development image"
	@echo "  make build-prod - Build production image"
	@echo "  make dev        - Start in development mode"
	@echo "  make prod       - Start in production mode"
	@echo "  make up         - Start containers (default: dev)"
	@echo "  make down       - Stop containers"
	@echo "  make restart    - Restart containers"
	@echo "  make logs       - View logs"
	@echo "  make shell      - Open shell in container"
	@echo "  make status     - Show container status"
	@echo "  make health     - Check health status"
	@echo "  make test       - Run tests in container"
	@echo "  make clean      - Remove containers and images"

# Build targets
build: build-dev

build-dev:
	docker-compose -f docker-compose.dev.yml build

build-prod:
	docker-compose -f docker-compose.prod.yml build

# Run targets
dev: build-dev
	docker-compose -f docker-compose.dev.yml up -d
	@echo "Development server started at http://localhost:4567"

prod: build-prod
	docker-compose -f docker-compose.prod.yml up -d
	@echo "Production server started"

up: dev

# Stop targets
down:
	docker-compose -f docker-compose.dev.yml down 2>/dev/null || true
	docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

# Restart targets
restart-dev:
	docker-compose -f docker-compose.dev.yml restart

restart-prod:
	docker-compose -f docker-compose.prod.yml restart

restart: restart-dev

# Logs
logs:
	@if docker ps | grep -q robot-tank-dev; then \
		docker-compose -f docker-compose.dev.yml logs -f; \
	elif docker ps | grep -q robot-tank-prod; then \
		docker-compose -f docker-compose.prod.yml logs -f; \
	else \
		echo "No robot containers running"; \
	fi

logs-dev:
	docker-compose -f docker-compose.dev.yml logs -f

logs-prod:
	docker-compose -f docker-compose.prod.yml logs -f

# Shell access
shell:
	@if docker ps | grep -q robot-tank-dev; then \
		docker-compose -f docker-compose.dev.yml exec robot bash; \
	elif docker ps | grep -q robot-tank-prod; then \
		docker-compose -f docker-compose.prod.yml exec robot bash; \
	else \
		echo "No robot containers running"; \
	fi

shell-dev:
	docker-compose -f docker-compose.dev.yml exec robot bash

shell-prod:
	docker-compose -f docker-compose.prod.yml exec robot bash

# Status
status:
	@echo "=== Container Status ==="
	@docker ps -a | grep robot || echo "No robot containers found"
	@echo ""
	@echo "=== Image Status ==="
	@docker images | grep robot || echo "No robot images found"

health:
	@if docker ps | grep -q robot-tank-dev; then \
		curl -f http://localhost:4567/health && echo " - Dev container healthy"; \
	fi
	@if docker ps | grep -q robot-tank-prod; then \
		curl -f http://localhost/health && echo " - Prod container healthy"; \
	fi

# Testing
test:
	docker-compose -f docker-compose.dev.yml exec robot bundle exec rspec

# Clean up
clean:
	docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true
	docker-compose -f docker-compose.prod.yml down -v 2>/dev/null || true
	docker rmi robot-tank:latest robot-tank:dev 2>/dev/null || true
	@echo "Cleanup complete"

clean-logs:
	rm -rf logs/*
	@echo "Logs cleaned"

# Rebuild without cache
rebuild-dev:
	docker-compose -f docker-compose.dev.yml build --no-cache
	docker-compose -f docker-compose.dev.yml up -d

rebuild-prod:
	docker-compose -f docker-compose.prod.yml build --no-cache
	docker-compose -f docker-compose.prod.yml up -d

# Pull latest code and rebuild
update:
	git pull
	make clean
	make build

# Show resource usage
stats:
	docker stats --no-stream | grep robot || echo "No robot containers running"
