'use client'

import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { UserConsent } from '@/components/UserConsent'
import Link from 'next/link'

export default function ConsentPage() {
  const { data: session, status } = useSession()
  const router = useRouter()

  if (status === 'loading') {
    return (
      <main className="container">
        <article aria-busy="true" style={{ minHeight: '200px' }}>
          <p className="text-center">Loading...</p>
        </article>
      </main>
    )
  }

  if (!session) {
    router.push('/')
    return null
  }

  return (
    <main className="container">
      <nav style={{ marginTop: '2rem', marginBottom: '2rem' }}>
        <ul>
          <li><Link href="/">← Back to Home</Link></li>
        </ul>
      </nav>
      
      <article style={{ marginBottom: '2rem' }}>
        <header className="text-center mb-4">
          <h1 className="header-gradient">Consent Management</h1>
          <p>Control which applications can act on your behalf</p>
        </header>
      </article>

      <UserConsent />
    </main>
  )
}