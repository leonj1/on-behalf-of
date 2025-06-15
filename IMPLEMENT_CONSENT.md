# IMPLEMENT_CONSENT.md - Implementation Plan

## Overview
This plan aligns the current system with the sequence diagram, with clear URL contracts for the consent flow, a discovery endpoint for Service B's consent requirements, and Material UI light theme for the consent UI.

## Consent URL Contract Specification

### Service A Response (403 Forbidden)
When consent is missing, Service A returns:
```json
{
  "error_code": "consent_required",
  "destination_service": "service-b",
  "destination_service_name": "Banking Service",
  "operations": ["withdraw"],
  "client_id": "nextjs-app",
  "consent_ui_url": "http://100.68.45.127:8012/consent",
  "consent_params": {
    "requesting_service": "service-a",
    "requesting_service_name": "Service A",
    "destination_service": "service-b",
    "operations": "withdraw",
    "redirect_uri": "http://10.1.1.74:3005/consent-callback",
    "state": "<random-state-token>"
  }
}
```

### Frontend Redirect to Consent UI
Frontend constructs the full consent URL:
```
http://100.68.45.127:8012/consent?
  requesting_service=service-a&
  requesting_service_name=Service%20A&
  destination_service=service-b&
  operations=withdraw&
  redirect_uri=http%3A%2F%2F10.1.1.74%3A3005%2Fconsent-callback&
  state=<random-state-token>&
  user_token=<user-jwt-token>
```

### Service B Consent UI Response
After consent decision, Service B redirects to:
- **On Grant**: `http://10.1.1.74:3005/consent-callback?granted=true&state=<state-token>`
- **On Deny**: `http://10.1.1.74:3005/consent-callback?granted=false&state=<state-token>`

## Phase 1: Add Consent Discovery Endpoint to Service B
- [x] 1.1 Create GET `/consent.json` endpoint (no authentication required) that returns:
  ```json
  {
    "service_id": "service-b",
    "service_name": "Banking Service",
    "consent_ui_url": "http://100.68.45.127:8012/consent",
    "consent_required_endpoints": [
      {
        "method": "POST",
        "path": "/withdraw",
        "description": "Withdraw funds from account",
        "required_capabilities": ["withdraw"],
        "capability_descriptions": {
          "withdraw": "Allow withdrawal of funds from your bank account"
        }
      },
      {
        "method": "GET",
        "path": "/balance",
        "description": "View account balance",
        "required_capabilities": ["view_balance"],
        "capability_descriptions": {
          "view_balance": "View your current account balance"
        }
      },
      {
        "method": "POST",
        "path": "/transfer",
        "description": "Transfer funds between accounts",
        "required_capabilities": ["transfer", "view_balance"],
        "capability_descriptions": {
          "transfer": "Transfer funds to other accounts",
          "view_balance": "View balance to verify sufficient funds"
        }
      }
    ],
    "all_capabilities": [
      {
        "name": "withdraw",
        "display_name": "Withdraw Funds",
        "description": "Allows services to withdraw funds from your account on your behalf",
        "risk_level": "high"
      },
      {
        "name": "view_balance",
        "display_name": "View Balance",
        "description": "Allows services to check your account balance",
        "risk_level": "low"
      },
      {
        "name": "transfer",
        "display_name": "Transfer Funds",
        "description": "Allows services to transfer funds between accounts",
        "risk_level": "high"
      }
    ],
    "consent_metadata": {
      "version": "1.0",
      "last_updated": "2024-01-15T00:00:00Z",
      "contact_email": "support@banking-service.com"
    }
  }
  ```

- [x] 1.2 Ensure consent.json is accessible without authentication
- [x] 1.3 Add CORS headers to allow cross-origin access
- [x] 1.4 Cache the response with appropriate headers

## Phase 2: Enhance Service A's Response Format
- [x] 2.1 Update Service A to optionally fetch Service B's consent.json
- [x] 2.2 Include capability descriptions in the 403 response:
  ```json
  {
    "error_code": "consent_required",
    "destination_service": "service-b",
    "destination_service_name": "Banking Service",
    "operations": ["withdraw"],
    "operation_descriptions": {
      "withdraw": "Allow withdrawal of funds from your bank account"
    },
    "client_id": "nextjs-app",
    "consent_ui_url": "http://100.68.45.127:8012/consent",
    "consent_params": { ... }
  }
  ```

## Phase 3: Add Material UI Consent UI to Service B
- [x] 3.1 Create static HTML template for consent UI with:
  - [x] Material UI light theme via CDN
  - [x] Responsive design following Material Design principles
  - [x] Clean, professional banking interface

- [x] 3.2 Consent UI HTML structure:
  ```html
  <!DOCTYPE html>
  <html>
  <head>
    <title>Consent Request - Banking Service</title>
    <!-- Material UI CSS -->
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap">
    <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
    <style>
      /* Material UI light theme custom styles */
      body {
        font-family: 'Roboto', sans-serif;
        background-color: #fafafa;
        margin: 0;
        padding: 0;
      }
      .consent-container {
        max-width: 600px;
        margin: 40px auto;
        background: #ffffff;
        border-radius: 4px;
        box-shadow: 0px 2px 4px rgba(0,0,0,0.1);
      }
      /* Additional Material Design styling */
    </style>
  </head>
  <body>
    <!-- Consent UI content -->
  </body>
  </html>
  ```

- [x] 3.3 Material UI Components to include:
  - [x] AppBar with Banking Service logo/name
  - [x] Card component for main consent form
  - [x] Alert component for important notices
  - [x] Chip components for capability tags
  - [x] Button components (contained style for Grant, outlined for Deny)
  - [x] Linear progress indicator during processing

- [x] 3.4 Consent form layout:
  - [x] Header: "Consent Request"
  - [x] Service info: "[Service A] is requesting permission to:"
  - [x] Capabilities list with Material Icons:
    - 💰 Withdraw Funds (High Risk) - shown with error color
    - 👁️ View Balance (Low Risk) - shown with success color
  - [x] User info section showing who's granting consent
  - [x] Action buttons with proper Material spacing

- [x] 3.5 Create POST `/consent/decision` endpoint
- [x] 3.6 Add loading states and error handling with Material UI components
- [x] 3.7 Implement smooth transitions per Material Design

## Phase 4: Update Frontend Consent Handling
- [x] 4.1 Create `/consent-callback` route
- [x] 4.2 Handle consent-required errors with proper state management
- [x] 4.3 Show Material UI Snackbar notifications for consent status
- [x] 4.4 Retry original request after successful consent

## Phase 5: Update Consent Store Integration
- [ ] 5.1 Ensure consent store handles the exact format
- [ ] 5.2 Add capability metadata storage
- [ ] 5.3 Banking service registers capabilities on startup

## Phase 6: Material UI Implementation Details
- [ ] 6.1 Use Material UI color palette:
  - Primary: Blue 500 (#2196F3)
  - Secondary: Light Blue 500 (#03A9F4)
  - Error: Red 500 (#F44336) for high-risk operations
  - Success: Green 500 (#4CAF50) for low-risk operations
  - Background: Grey 50 (#FAFAFA)

- [ ] 6.2 Follow Material Design spacing:
  - 8dp grid system
  - 16dp padding for cards
  - 24dp margins between sections

- [ ] 6.3 Implement Material animations:
  - Fade in on load
  - Ripple effect on buttons
  - Smooth transitions between states

- [ ] 6.4 Ensure accessibility:
  - ARIA labels
  - Keyboard navigation
  - High contrast ratios

## Phase 7: Security and Standards
- [ ] 7.1 Implement redirect_uri whitelist
- [ ] 7.2 Add rate limiting
- [ ] 7.3 CSRF protection with state tokens
- [ ] 7.4 XSS protection in consent UI

## Phase 8: Testing
- [ ] 8.1 Test Material UI rendering across browsers
- [ ] 8.2 Test responsive design on mobile devices
- [ ] 8.3 Test full consent flow
- [ ] 8.4 Test accessibility compliance

## Material UI Consent Page Example
```
┌─────────────────────────────────────────┐
│  🏦 Banking Service                     │
├─────────────────────────────────────────┤
│                                         │
│  Consent Request                        │
│                                         │
│  Service A is requesting permission to: │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 💰 Withdraw Funds     [HIGH RISK]│   │
│  │    Allow withdrawal of funds     │   │
│  │    from your bank account       │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Granting consent for: admin@email.com │
│                                         │
│  ┌─────────┐  ┌─────────┐              │
│  │  GRANT  │  │  DENY   │              │
│  └─────────┘  └─────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

This ensures a professional, consistent Material UI light theme experience for the banking service consent UI.