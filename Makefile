# Docker-based development for Mudda. See DOCKER.md for details.
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
	@echo "  Mudda is starting at http://app.mudda.localhost:3006 (or http://localhost:3006)"
	@echo "  Day 0: sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD, then enroll a passkey."

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
logs: ## Tail the server log
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
seed: ## Provision the owner account from MUDDA_OWNER_* env vars
	$(EXEC) bin/rails db:seed

.PHONY: reset-db
reset-db: ## Drop, recreate, and reseed the database
	$(EXEC) bin/rails db:reset

.PHONY: reset-auth
reset-auth: ## Reset auth to day 0 (delete passkeys+sessions, re-enable password login)
	$(RUN) bin/rails auth:reset

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
