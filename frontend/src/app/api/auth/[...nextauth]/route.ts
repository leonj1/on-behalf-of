import NextAuth from 'next-auth'
import KeycloakProvider from 'next-auth/providers/keycloak'

const handler = NextAuth({
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID || 'nextjs-app',
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET || '',
      issuer: process.env.KEYCLOAK_ISSUER || 'http://localhost:8080/realms/master',
      authorization: {
        params: {
          scope: 'openid email profile'
        },
        url: `${process.env.KEYCLOAK_ISSUER_PUBLIC || process.env.KEYCLOAK_ISSUER}/protocol/openid-connect/auth`
      },
      token: `${process.env.KEYCLOAK_ISSUER}/protocol/openid-connect/token`,
      userinfo: `${process.env.KEYCLOAK_ISSUER}/protocol/openid-connect/userinfo`,
    })
  ],
  callbacks: {
    async jwt({ token, account, profile }) {
      // Persist the OAuth access_token to the token right after signin
      if (account) {
        token.accessToken = account.access_token
        token.idToken = account.id_token
        // Decode the access token to get the actual user ID
        try {
          const payload = JSON.parse(Buffer.from(account.access_token.split('.')[1], 'base64').toString())
          token.sub = payload.sub // Get sub from the JWT payload
        } catch (e) {
          token.sub = account.providerAccountId // Fallback
        }
      }
      return token
    },
    async session({ session, token }) {
      // Send properties to the client
      session.accessToken = token.accessToken as string
      session.idToken = token.idToken as string
      session.user.id = token.sub as string // Add user ID to session
      return session
    },
    async redirect({ url, baseUrl }) {
      // Handle redirects to use the public URL for client-side
      if (url.startsWith('/')) return `${baseUrl}${url}`
      else if (new URL(url).origin === baseUrl) return url
      return baseUrl
    },
  },
})

export { handler as GET, handler as POST }