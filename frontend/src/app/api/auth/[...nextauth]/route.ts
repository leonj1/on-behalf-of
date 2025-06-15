import NextAuth from 'next-auth'
import KeycloakProvider from 'next-auth/providers/keycloak'

const handler = NextAuth({
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID || 'nextjs-app',
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET || '',
      issuer: process.env.KEYCLOAK_ISSUER || 'http://localhost:8080/realms/master',
      // Override the wellKnown endpoint to use the public URL
      wellKnown: `${process.env.KEYCLOAK_ISSUER || 'http://localhost:8080/realms/master'}/.well-known/openid-configuration`,
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
    async jwt({ token, account }) {
      // Persist the OAuth access_token to the token right after signin
      if (account) {
        token.accessToken = account.access_token
        token.idToken = account.id_token
      }
      return token
    },
    async session({ session, token }) {
      // Send properties to the client
      session.accessToken = token.accessToken as string
      session.idToken = token.idToken as string
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