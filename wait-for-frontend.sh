#!/bin/bash

until curl -sf http://localhost:3005/health > /dev/null 2>&1; do \
        echo "Consent UI is not ready yet..."; \
        echo "Consent UI is not ready yet..."; \
        sleep 2; \
done

echo "Consent UI is ready..."; \
