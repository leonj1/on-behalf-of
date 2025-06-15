'use client'

import { useSession, signIn, signOut } from 'next-auth/react'
import { useState, useEffect } from 'react'

export default function Home() {
  const { data: session, status } = useSession()
  const [helloMessage, setHelloMessage] = useState<string>('')
  const [withdrawMessage, setWithdrawMessage] = useState<string>('')
  const [error, setError] = useState<string>('')
  const [loading, setLoading] = useState<{ hello: boolean; withdraw: boolean }>({ hello: false, withdraw: false })
  const [consentRequired, setConsentRequired] = useState<any>(null)

  // Check for messages from consent callback
  useEffect(() => {
    // Check for successful withdrawal after consent
    const withdrawSuccess = sessionStorage.getItem('withdrawSuccess')
    if (withdrawSuccess) {
      const data = JSON.parse(withdrawSuccess)
      setWithdrawMessage(JSON.stringify(data, null, 2))
      sessionStorage.removeItem('withdrawSuccess')
    }
    
    // Check for withdrawal error after consent
    const withdrawError = sessionStorage.getItem('withdrawError')
    if (withdrawError) {
      const errorData = JSON.parse(withdrawError)
      if (errorData.status === 403) {
        setError('Access denied: The consent may not have been properly saved. Please try granting consent again.')
      } else {
        setError(`Error ${errorData.status}: ${errorData.detail}`)
      }
      sessionStorage.removeItem('withdrawError')
    }
    
    // Check for consent denial
    const consentDenied = sessionStorage.getItem('consentDenied')
    if (consentDenied) {
      setError('Consent was denied. You need to grant consent to perform this action.')
      sessionStorage.removeItem('consentDenied')
    }
  }, [])

  const callHelloService = async () => {
    setLoading({ ...loading, hello: true })
    try {
      const response = await fetch('http://10.1.1.74:8003/hello')
      const data = await response.text()
      setHelloMessage(data)
      setError('')
    } catch (err) {
      setError('Failed to call hello service')
    } finally {
      setLoading({ ...loading, hello: false })
    }
  }

  const callBankingService = async () => {
    if (!session?.accessToken) {
      setError('No access token available')
      return
    }

    setLoading({ ...loading, withdraw: true })
    try {
      const response = await fetch('http://10.1.1.74:8004/withdraw', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.accessToken}`,
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        setWithdrawMessage(JSON.stringify(data, null, 2))
        setError('')
      } else {
        const errorData = await response.json()
        
        // Check if it's a consent required error
        if (errorData.detail && errorData.detail.error_code === 'consent_required') {
          // Redirect to consent UI
          const consentParams = errorData.detail.consent_params
          const params = new URLSearchParams({
            ...consentParams,
            user_token: session.accessToken
          })
          const consentUrl = `${errorData.detail.consent_ui_url}?${params}`
          window.location.href = consentUrl
        } else {
          setError(`Banking service error: ${errorData.detail || response.statusText}`)
          setWithdrawMessage('')
        }
      }
    } catch (err) {
      setError('Failed to call banking service')
      setWithdrawMessage('')
    } finally {
      setLoading({ ...loading, withdraw: false })
    }
  }

  if (status === 'loading') {
    return (
      <main className="container">
        <article aria-busy="true" style={{ minHeight: '200px' }}>
          <p className="text-center">Loading authentication status...</p>
        </article>
      </main>
    )
  }

  if (!session) {
    return (
      <main className="container">
        <article style={{ maxWidth: '600px', margin: '5rem auto', padding: '3rem' }}>
          <header className="text-center mb-4">
            <h1 className="header-gradient">On-Behalf-Of Demo</h1>
            <p>Experience OAuth2 flow with consent management</p>
          </header>
          
          <div className="text-center">
            <p style={{ marginBottom: '2rem', color: 'var(--pico-muted-color)' }}>
              Sign in with your Keycloak account to access protected services
            </p>
            <button 
              onClick={() => signIn('keycloak')}
              className="btn-gradient-primary"
              style={{ width: '100%', padding: '1rem', fontSize: '1.1rem' }}
            >
              🔐 Sign in with Keycloak
            </button>
          </div>
        </article>
      </main>
    )
  }

  return (
    <main className="container">
      <article style={{ marginTop: '2rem', marginBottom: '2rem' }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
          <div>
            <h1 className="header-gradient" style={{ marginBottom: '0.5rem' }}>
              Welcome, {session.user?.name || session.user?.email}
            </h1>
            <p style={{ color: 'var(--pico-muted-color)', margin: 0 }}>
              You are successfully authenticated
            </p>
          </div>
          <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
            <a href="/consent" className="btn-gradient-primary" style={{ padding: '0.75rem 1.5rem', textDecoration: 'none' }}>
              Manage Consents
            </a>
            <button
              onClick={() => signOut()}
              className="btn-gradient-danger"
              style={{ padding: '0.75rem 1.5rem' }}
            >
              Sign out
            </button>
          </div>
        </header>

        <div className="grid" style={{ gap: '2rem', marginTop: '3rem' }}>
          <article style={{ padding: '2rem' }}>
            <header>
              <h3 style={{ marginBottom: '0.5rem' }}>🌟 Hello Service</h3>
              <p style={{ color: 'var(--pico-muted-color)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
                Unprotected endpoint - No authentication required
              </p>
            </header>
            
            <button
              onClick={callHelloService}
              className="btn-gradient-success"
              aria-busy={loading.hello}
              disabled={loading.hello}
              style={{ width: '100%', padding: '1rem' }}
            >
              {loading.hello ? 'Calling...' : 'Say Hello'}
            </button>
            
            {helloMessage && (
              <div className="response-box response-success">
                <strong>Response:</strong> {helloMessage}
              </div>
            )}
          </article>

          <article style={{ padding: '2rem' }}>
            <header>
              <h3 style={{ marginBottom: '0.5rem' }}>💰 Banking Service</h3>
              <p style={{ color: 'var(--pico-muted-color)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
                Protected endpoint - Requires consent and JWT validation
              </p>
            </header>
            
            <button
              onClick={callBankingService}
              className="btn-gradient-purple"
              aria-busy={loading.withdraw}
              disabled={loading.withdraw}
              style={{ width: '100%', padding: '1rem' }}
            >
              {loading.withdraw ? 'Processing...' : 'Empty Bank Account'}
            </button>
            
            {withdrawMessage && (
              <div className="response-box response-info">
                <strong>Response:</strong>
                <pre style={{ margin: '0.5rem 0 0 0', whiteSpace: 'pre-wrap' }}>
                  {withdrawMessage}
                </pre>
              </div>
            )}
          </article>
        </div>

        {error && (
          <article style={{ marginTop: '2rem', padding: '1.5rem' }}>
            <div className="response-box response-error" style={{ margin: 0 }}>
              <strong>⚠️ Error:</strong> {error}
            </div>
          </article>
        )}
      </article>
    </main>
  )
}