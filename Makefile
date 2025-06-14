.PHONY: start stop restart logs ps

start:
	docker compose up -d
	@echo "Waiting for Keycloak to be ready..."
	@until curl -sf http://localhost:8080/ > /dev/null 2>&1; do \
		echo "Keycloak is not ready yet..."; \
		sleep 5; \
	done
	@echo "Keycloak is ready!"

stop:
	docker compose down

restart: stop start

logs:
	docker compose logs -f

ps:
	docker compose ps
