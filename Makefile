.PHONY: all start start-backend start-frontend stop restart logs ps setup-clients setup-consent-store setup show-secrets clean-clients configure-google-auth

# Default target - runs complete setup
all: setup show-secrets
	@echo ""
	@echo "========================================="
	@echo "✓ All services are running and configured!"
	@echo "========================================="
	@echo ""
	@echo "Next steps:"
	@echo "1. Access Keycloak admin: http://$${EXTERNAL_IP:-100.68.45.127}:$${KEYCLOAK_PORT:-8080} (admin/admin)"
	@echo "2. Access Frontend: http://$${FRONTEND_EXTERNAL_IP:-10.1.1.74}:$${FRONTEND_PORT:-3005}"
	@echo "3. View logs: make logs"
	@echo ""
	@echo "For client credentials, run: make show-secrets"

start:
	docker-compose up -d
	@echo "Waiting for Keycloak to be ready..."
	@until curl -sf http://localhost:$${KEYCLOAK_PORT:-8080}/ > /dev/null 2>&1; do \
		echo "Keycloak is not ready yet..."; \
		sleep 5; \
	done
	@echo "Keycloak is ready!"
	@./configure-keycloak.sh

start-backend:
	@echo "Starting backend services (excluding frontend)..."
	@docker-compose up -d keycloak consent-store banking-service hello service-a
	@echo "Waiting for Keycloak to be ready..."
	@until curl -sf http://localhost:$${KEYCLOAK_PORT:-8080}/ > /dev/null 2>&1; do \
		echo "Keycloak is not ready yet..."; \
		sleep 5; \
	done
	@echo "Keycloak is ready!"
	@./configure-keycloak.sh

start-frontend:
	@echo "Starting frontend with finalized client secrets..."
	@docker-compose up -d frontend

stop:
	docker-compose down

restart: stop start

logs:
	docker-compose logs -f

ps:
	docker-compose ps

setup-clients:
	@echo "Creating Keycloak client IDs..."
	@echo "----------------------------------------"
	@echo "Ensuring Keycloak is ready for client operations..."
	@until docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin --client admin-cli > /dev/null 2>&1; do \
		echo "Waiting for Keycloak admin access..."; \
		sleep 3; \
	done
	@echo "✓ Keycloak admin access confirmed"
	@echo ""
	@echo "Creating client: service-a"
	@python3 create-clientid.py --client-id service-a || echo "Client service-a may already exist"
	@echo ""
	@echo "Creating client: service-b"
	@python3 create-clientid.py --client-id service-b || echo "Client service-b may already exist"
	@echo ""
	@echo "Creating client: nextjs-app"
	@python3 create-clientid.py --client-id nextjs-app || echo "Client nextjs-app may already exist"
	@echo ""
	@echo "Updating nextjs-app redirect URIs..."
	@./update-nextjs-client.sh
	@echo ""
	@echo "Fixing token exchange permissions..."
	@./fix-token-exchange-permissions.sh
	@echo ""
	@echo "Updating frontend client secret..."
	@./update-frontend-secret.sh
	@echo ""
	@echo "Updating service-a client secret..."
	@./update-service-a-secret.sh
	@echo ""
	@echo "Updating service-b client secret..."
	@./update-service-b-secret.sh
	@echo "----------------------------------------"
	@echo "✓ All clients created and secrets synchronized"

setup-consent-store:
	@echo "Setting up consent store applications..."
	@echo "----------------------------------------"
	@echo "Waiting for consent-store to be ready..."
	@until curl -sf http://localhost:$${CONSENT_STORE_PORT:-8001}/health > /dev/null 2>&1; do \
		echo "Consent store is not ready yet..."; \
		sleep 2; \
	done
	@echo "✓ Consent store is ready"
	@echo ""
	@echo "Registering applications..."
	@curl -s -X POST http://localhost:$${CONSENT_STORE_PORT:-8001}/applications \
		-H "Content-Type: application/json" \
		-d '{"name": "service-a"}' > /dev/null && echo "✓ Registered service-a" || echo "⚠ service-a may already exist"
	@curl -s -X POST http://localhost:$${CONSENT_STORE_PORT:-8001}/applications \
		-H "Content-Type: application/json" \
		-d '{"name": "service-b"}' > /dev/null && echo "✓ Registered service-b" || echo "⚠ service-b may already exist"
	@echo ""
	@echo "Adding capabilities..."
	@APP_ID=$$(curl -s http://localhost:$${CONSENT_STORE_PORT:-8001}/applications | jq -r '.[] | select(.name=="service-b") | .id'); \
	if [ -n "$$APP_ID" ]; then \
		curl -s -X PUT http://localhost:$${CONSENT_STORE_PORT:-8001}/applications/$$APP_ID/capabilities \
			-H "Content-Type: application/json" \
			-d '{"capability": "withdraw"}' > /dev/null && echo "✓ Added 'withdraw' capability to service-b"; \
		curl -s -X PUT http://localhost:$${CONSENT_STORE_PORT:-8001}/applications/$$APP_ID/capabilities \
			-H "Content-Type: application/json" \
			-d '{"capability": "view_balance"}' > /dev/null && echo "✓ Added 'view_balance' capability to service-b"; \
		curl -s -X PUT http://localhost:$${CONSENT_STORE_PORT:-8001}/applications/$$APP_ID/capabilities \
			-H "Content-Type: application/json" \
			-d '{"capability": "transfer"}' > /dev/null && echo "✓ Added 'transfer' capability to service-b"; \
	else \
		echo "✗ Could not find service-b application ID"; \
	fi
	@echo "----------------------------------------"
	@echo "✓ Consent store setup complete"

wait-for-consent-ui:
	./wait-for-frontend.sh

setup: start-backend setup-clients setup-consent-store start-frontend wait-for-consent-ui
	@echo ""
	@echo "========================================="
	@echo "✓ Full setup complete!"
	@echo "========================================="
	@echo ""

setup-with-fallback: start-backend
	@echo "Setting up with authentication fallback..."
	@./setup-auth-with-fallback.sh
	@echo ""
	@SKIP_TOKEN_EXCHANGE_CHECK=true $(MAKE) setup-clients
	@$(MAKE) setup-consent-store
	@$(MAKE) start-frontend
	@$(MAKE) wait-for-consent-ui
	@echo ""
	@echo "========================================="
	@echo "✓ Setup complete with fallback auth!"
	@echo "========================================="
	@echo ""
	@echo "Services available at:"
	@echo "  - Keycloak:      http://$${EXTERNAL_IP:-100.68.45.127}:$${KEYCLOAK_PORT:-8080} (admin/admin)"
	@echo "  - Consent Store: http://localhost:$${CONSENT_STORE_PORT:-8001}"
	@echo "  - Banking Service: http://localhost:$${BANKING_SERVICE_PORT:-8012}"
	@echo "  - Hello Service: http://localhost:$${HELLO_SERVICE_PORT:-8003}"
	@echo "  - Service A:     http://localhost:$${SERVICE_A_PORT:-8004}"
	@echo "  - Frontend:      http://$${FRONTEND_EXTERNAL_IP:-10.1.1.74}:$${FRONTEND_PORT:-3005}"
	@echo ""
	@echo "To view logs: make logs"
	@echo "To stop all services: make stop"

show-secrets:
	@echo "Fetching client secrets from Keycloak..."
	@echo "========================================="
	@docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
		--server http://localhost:$${KEYCLOAK_PORT:-8080} \
		--realm master \
		--user admin \
		--password admin \
		--client admin-cli > /dev/null 2>&1
	@echo "service-a:"
	@CLIENT_UUID=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id'); \
	if [ -n "$$CLIENT_UUID" ]; then \
		SECRET=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$$CLIENT_UUID/client-secret -r master | jq -r '.value'); \
		echo "  Client ID: service-a"; \
		echo "  Secret: $$SECRET"; \
	fi
	@echo ""
	@echo "service-b:"
	@CLIENT_UUID=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id'); \
	if [ -n "$$CLIENT_UUID" ]; then \
		SECRET=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$$CLIENT_UUID/client-secret -r master | jq -r '.value'); \
		echo "  Client ID: service-b"; \
		echo "  Secret: $$SECRET"; \
	fi
	@echo ""
	@echo "nextjs-app:"
	@CLIENT_UUID=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id'); \
	if [ -n "$$CLIENT_UUID" ]; then \
		SECRET=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$$CLIENT_UUID/client-secret -r master | jq -r '.value'); \
		echo "  Client ID: nextjs-app"; \
		echo "  Secret: $$SECRET"; \
	fi
	@echo "========================================="

clean-clients:
	@echo "Cleaning up Keycloak clients and consent store data..."
	@echo "----------------------------------------"
	@docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
		--server http://localhost:$${KEYCLOAK_PORT:-8080} \
		--realm master \
		--user admin \
		--password admin \
		--client admin-cli > /dev/null 2>&1
	@for client in service-a service-b nextjs-app; do \
		CLIENT_UUID=$$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r ".[] | select(.clientId==\"$$client\") | .id"); \
		if [ -n "$$CLIENT_UUID" ]; then \
			docker exec keycloak /opt/keycloak/bin/kcadm.sh delete clients/$$CLIENT_UUID -r master && echo "✓ Deleted client: $$client"; \
		fi; \
	done
	@echo ""
	@echo "Cleaning consent store..."
	@if curl -sf http://localhost:$${CONSENT_STORE_PORT:-8001}/health > /dev/null 2>&1; then \
		curl -s -X DELETE http://localhost:$${CONSENT_STORE_PORT:-8001}/consent/all > /dev/null && echo "✓ Cleared all consents"; \
		APPS=$$(curl -s http://localhost:$${CONSENT_STORE_PORT:-8001}/applications | jq -r '.[] | .id'); \
		for app_id in $$APPS; do \
			curl -s -X DELETE http://localhost:$${CONSENT_STORE_PORT:-8001}/applications/$$app_id > /dev/null && echo "✓ Deleted application ID: $$app_id"; \
		done; \
	else \
		echo "⚠ Consent store not available"; \
	fi
	@echo "----------------------------------------"
	@echo "✓ Cleanup complete"

configure-google-auth:
	@if [ -z "$(GOOGLE_CLIENT_ID)" ] || [ -z "$(GOOGLE_CLIENT_SECRET)" ]; then \
		echo "❌ Error: Google OAuth credentials required"; \
		echo ""; \
		echo "Usage: make configure-google-auth GOOGLE_CLIENT_ID=your-client-id GOOGLE_CLIENT_SECRET=your-client-secret"; \
		echo ""; \
		echo "To obtain Google OAuth credentials:"; \
		echo "1. Go to https://console.cloud.google.com/"; \
		echo "2. Create a new project or select existing one"; \
		echo "3. Enable Google+ API"; \
		echo "4. Create OAuth 2.0 credentials"; \
		echo "5. Add authorized redirect URIs:"; \
		echo "   - http://localhost:$${KEYCLOAK_PORT:-8080}/realms/master/broker/google/endpoint"; \
		echo "   - http://$${EXTERNAL_IP:-100.68.45.127}:$${KEYCLOAK_PORT:-8080}/realms/master/broker/google/endpoint"; \
		echo ""; \
		echo "For detailed instructions, see GOOGLE_AUTH_SETUP.md"; \
		exit 1; \
	fi
	@echo "Configuring Google authentication in Keycloak..."
	@./configure-google-auth.sh "$(GOOGLE_CLIENT_ID)" "$(GOOGLE_CLIENT_SECRET)"

restart: stop all

