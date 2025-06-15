'use client'

import { useEffect, useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { useSession } from 'next-auth/react'

export default function ConsentCallbackPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { data: session } = useSession()
  const [message, setMessage] = useState('Processing consent decision...')
  
  useEffect(() => {
    const granted = searchParams.get('granted')
    const state = searchParams.get('state')
    
    // Validate state token (in production, check against stored state)
    if (!state) {
      setMessage('Invalid consent response: missing state token')
      return
    }
    
    if (granted === 'true') {
      setMessage('Consent granted! Retrying your request...')
      
      // Retry the original withdraw request
      if (session?.accessToken) {
        fetch('http://10.1.1.74:8004/withdraw', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.accessToken}`,
            'Content-Type': 'application/json'
          }
        })
        .then(async response => {
          if (response.ok) {
            const data = await response.json()
            // Store success message in session storage
            sessionStorage.setItem('withdrawSuccess', JSON.stringify(data))
            router.push('/')
          } else {
            const errorData = await response.json()
            // Store error details for display on main page
            sessionStorage.setItem('withdrawError', JSON.stringify({
              status: response.status,
              detail: errorData.detail || 'Request failed'
            }))
            router.push('/')
          }
        })
        .catch(error => {
          sessionStorage.setItem('withdrawError', JSON.stringify({
            status: 0,
            detail: 'Network error: Failed to complete withdrawal'
          }))
          router.push('/')
        })
      } else {
        router.push('/')
      }
    } else {
      setMessage('Consent denied. Redirecting...')
      // Store denial message
      sessionStorage.setItem('consentDenied', 'true')
      setTimeout(() => router.push('/'), 2000)
    }
  }, [searchParams, session, router])
  
  return (
    <main className="container">
      <article style={{ marginTop: '5rem', textAlign: 'center' }}>
        <div aria-busy="true" style={{ marginBottom: '2rem' }}></div>
        <h2>{message}</h2>
      </article>
    </main>
  )
}