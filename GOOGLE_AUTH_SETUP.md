# Google Authentication Setup for Keycloak

This guide explains how to configure Google as an identity provider for Keycloak in your local development environment.

## Prerequisites

- Keycloak is running (via `make run-keycloak` or `docker-compose up keycloak`)
- You have a Google account
- You have access to Google Cloud Console

## Step 1: Create a Google OAuth Application

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**
5. If prompted, configure the OAuth consent screen first:
   - Choose "External" user type for testing
   - Fill in the required fields (app name, user support email, developer contact)
   - Add your email to test users if using External type
   - You can skip optional fields for local development
6. For the OAuth client ID:
   - Application type: **Web application**
   - Name: `Keycloak Local Development` (or any name you prefer)
   - Authorized redirect URIs - Add these URIs:
     ```
     http://localhost:8080/realms/master/broker/google/endpoint
     http://localhost:8080/auth/realms/master/broker/google/endpoint
     ```
   - Click **Create**
7. Save the **Client ID** and **Client Secret** - you'll need these for configuration

## Step 2: Configure Keycloak with Google Authentication

1. Ensure Keycloak is running:
   ```bash
   make run-keycloak
   # or
   docker-compose up keycloak
   ```

2. Wait for Keycloak to be fully started (you should be able to access http://localhost:8080)

3. Run the configuration script with your Google OAuth credentials:
   ```bash
   ./configure-google-auth.sh YOUR_GOOGLE_CLIENT_ID YOUR_GOOGLE_CLIENT_SECRET
   ```

   Replace `YOUR_GOOGLE_CLIENT_ID` and `YOUR_GOOGLE_CLIENT_SECRET` with the values from Step 1.

4. The script will:
   - Authenticate with Keycloak admin
   - Create or update the Google identity provider
   - Configure the necessary settings
   - Display the redirect URI for verification

## Step 3: Verify the Configuration

1. Access Keycloak Admin Console:
   - URL: http://localhost:8080
   - Username: `admin`
   - Password: `admin`

2. Navigate to **Identity Providers** in the left menu
3. You should see "Google" listed and enabled
4. Click on Google to view/edit settings if needed

## Step 4: Test Google Login

1. Open a new incognito/private browser window
2. Go to http://localhost:8080/realms/master/account
3. You should see a "Sign in with Google" button on the login page
4. Click it and authenticate with your Google account
5. On first login, you may need to review and update your profile

## Troubleshooting

### Common Issues

1. **"Invalid redirect URI" error from Google:**
   - Ensure the redirect URI in your Google OAuth app matches exactly:
     ```
     http://localhost:8080/realms/master/broker/google/endpoint
     ```
   - Wait a few minutes for Google to propagate the changes

2. **"Identity provider not found" in Keycloak:**
   - Run the configuration script again
   - Check Keycloak logs: `docker logs keycloak`

3. **SSL/HTTPS issues:**
   - For local development, ensure SSL is disabled in Keycloak:
     ```bash
     ./configure-keycloak.sh
     ```

4. **Google login works but user can't access application:**
   - Check if the user needs specific roles assigned in Keycloak
   - Verify email verification settings

### Manual Configuration (Alternative)

If the script doesn't work, you can configure Google authentication manually:

1. Access Keycloak Admin Console
2. Go to **Identity Providers** > **Add provider** > **Google**
3. Set:
   - Client ID: Your Google OAuth client ID
   - Client Secret: Your Google OAuth client secret
   - Default Scopes: `openid profile email`
   - Store Tokens: ON
   - Trust Email: ON
   - Enabled: ON
4. Save the configuration

## Security Notes

- **Never commit credentials:** Don't commit your Google client ID and secret to version control
- **Use environment variables:** For production, use environment variables or secrets management
- **Restrict domains:** In production, configure Google OAuth to restrict to specific domains
- **Enable HTTPS:** Always use HTTPS in production environments

## Additional Configuration

### Restrict to Specific Domains

To restrict Google login to specific email domains (e.g., your company domain):

1. In Keycloak Admin Console, edit the Google identity provider
2. Add a custom mapper:
   - Name: `email-domain-validator`
   - Mapper Type: `Hardcoded Attribute`
   - Add validation for allowed domains

### First Login Flow

You can customize what happens when a user logs in with Google for the first time:

1. Go to **Authentication** > **Flows**
2. Copy the "first broker login" flow
3. Customize the steps (e.g., require email verification, profile review)
4. Update the Google identity provider to use your custom flow

## Related Scripts

- `./configure-keycloak.sh` - Configures basic Keycloak settings (SSL, etc.)
- `./create-test-user.sh` - Creates a test user for local development
- `./disable-keycloak-ssl.sh` - Disables SSL requirements for local development