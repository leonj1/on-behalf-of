import { getServerSession } from 'next-auth'
import { NextResponse } from 'next/server'
import NextAuth from 'next-auth'
import KeycloakProvider from 'next-auth/providers/keycloak'

// Copy the auth config to get session
const authOptions = {
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID || 'nextjs-app',
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET || '',
      issuer: process.env.KEYCLOAK_ISSUER || 'http://localhost:8080/realms/master',
    })
  ],
  callbacks: {
    async jwt({ token, account }: any) {
      if (account) {
        token.accessToken = account.access_token
        token.idToken = account.id_token
        try {
          const payload = JSON.parse(Buffer.from(account.access_token.split('.')[1], 'base64').toString())
          token.sub = payload.sub
        } catch (e) {
          token.sub = account.providerAccountId
        }
      }
      return token
    },
    async session({ session, token }: any) {
      session.accessToken = token.accessToken as string
      session.idToken = token.idToken as string
      session.user.id = token.sub as string
      return session
    },
  },
}

export async function GET() {
  const session = await getServerSession(authOptions)
  
  if (!session) {
    return NextResponse.json({ error: 'Not authenticated' }, { status: 401 })
  }

  // Decode the access token to show what's in it
  let tokenPayload = null
  try {
    if (session.accessToken) {
      tokenPayload = JSON.parse(
        Buffer.from(session.accessToken.split('.')[1], 'base64').toString()
      )
    }
  } catch (e) {
    // Ignore decode errors
  }

  return NextResponse.json({
    session: {
      user: session.user,
      accessToken: session.accessToken ? 'present' : 'missing',
      idToken: session.idToken ? 'present' : 'missing',
    },
    tokenPayload: tokenPayload ? {
      sub: tokenPayload.sub,
      email: tokenPayload.email,
      preferred_username: tokenPayload.preferred_username,
      aud: tokenPayload.aud,
    } : null
  })
}