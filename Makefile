# Docker-based development for Fizzy. See DOCKER.md for details.
# Run `make` or `make help` to list targets.

COMPOSE := docker compose
SERVICE := web
# Wrap one-off rails commands in a throwaway container so they work whether or
# not the server is already running.
RUN     := $(COMPOSE) run --rm $(SERVICE)
EXEC    := $(COMPOSE) exec $(SERVICE)

.DEFAULT_GOAL := help

##@ Getting started

.PHONY: setup
setup: ## Build the image and start the app in the background (first run)
	$(COMPOSE) up --build -d
	@echo
	@echo "  Fizzy is starting at http://app.fizzy.localhost:3006 (or http://localhost:3006)"
	@echo "  Log in as david@example.com — grab the magic link with: make logs"

.PHONY: up
up: ## Start the app in the foreground (Ctrl-C to stop)
	$(COMPOSE) up

.PHONY: start
start: ## Start the app in the background
	$(COMPOSE) up -d

.PHONY: build
build: ## Rebuild the image (run after changing the Gemfile)
	$(COMPOSE) build

.PHONY: down
down: ## Stop the app, keeping data
	$(COMPOSE) down

.PHONY: fresh
fresh: ## Wipe all data and rebuild from scratch (no customer data)
	$(COMPOSE) down -v
	$(COMPOSE) up --build -d

##@ Day to day

.PHONY: logs
logs: ## Tail the server log (magic login links appear here)
	$(COMPOSE) logs -f $(SERVICE)

.PHONY: ps
ps: ## Show container status
	$(COMPOSE) ps

.PHONY: console
console: ## Open a Rails console
	$(EXEC) bin/rails console

.PHONY: shell
shell: ## Open a bash shell in the container
	$(EXEC) bash

.PHONY: restart
restart: ## Restart the web service
	$(COMPOSE) restart $(SERVICE)

##@ Database

.PHONY: migrate
migrate: ## Run pending migrations
	$(EXEC) bin/rails db:migrate

.PHONY: seed
seed: ## Load development seed data (david@example.com account)
	$(EXEC) bin/rails db:seed

.PHONY: reset-db
reset-db: ## Drop, recreate, and reseed the database
	$(EXEC) bin/rails db:reset

##@ Quality

.PHONY: test
test: ## Run the unit test suite
	$(RUN) bin/rails test

.PHONY: lint
lint: ## Run RuboCop
	$(RUN) bin/rubocop

.PHONY: lint-fix
lint-fix: ## Run RuboCop with autocorrect
	$(RUN) bin/rubocop -a

##@ Help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo
