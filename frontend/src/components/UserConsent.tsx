'use client'

import { useState, useEffect } from 'react'
import { useSession } from 'next-auth/react'

interface Consent {
  id: number
  user_id: string
  requesting_app_name: string
  destination_app_name: string
  capability: string
  granted_at: string
}

interface Application {
  id: number
  name: string
  capabilities: string[]
}

export function UserConsent() {
  const { data: session } = useSession()
  const [consents, setConsents] = useState<Consent[]>([])
  const [applications, setApplications] = useState<Application[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [showGrantForm, setShowGrantForm] = useState(false)
  const [grantForm, setGrantForm] = useState({
    requesting_app: '',
    destination_app: '',
    capability: ''
  })

  const userId = session?.user?.email || session?.user?.name || 'unknown'

  const fetchConsents = async () => {
    if (!session?.user) return

    try {
      const response = await fetch(`http://10.1.1.74:8001/consent/user/${userId}`)
      if (response.ok) {
        const data = await response.json()
        setConsents(data)
      } else if (response.status === 404) {
        // No consents found for user - this is normal
        setConsents([])
      } else {
        setError('Failed to fetch consents')
      }
    } catch (err) {
      console.error('Error fetching consents:', err)
      setError('Error fetching consents. Please check if the consent store is running.')
    } finally {
      setLoading(false)
    }
  }

  const fetchApplications = async () => {
    try {
      const response = await fetch('http://10.1.1.74:8001/applications')
      if (response.ok) {
        const apps = await response.json()
        // Fetch capabilities for each app
        const appsWithCapabilities = await Promise.all(
          apps.map(async (app: any) => {
            const capResponse = await fetch(`http://10.1.1.74:8001/applications/${app.id}/capabilities`)
            const capabilities = capResponse.ok ? await capResponse.json() : []
            return { ...app, capabilities }
          })
        )
        setApplications(appsWithCapabilities)
      }
    } catch (err) {
      console.error('Error fetching applications:', err)
    }
  }

  const grantConsent = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    try {
      const response = await fetch('http://10.1.1.74:8001/consent', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          user_id: userId,
          requesting_app_name: grantForm.requesting_app,
          destination_app_name: grantForm.destination_app,
          capabilities: [grantForm.capability]
        })
      })

      if (response.ok) {
        setSuccess('Consent granted successfully')
        setShowGrantForm(false)
        setGrantForm({ requesting_app: '', destination_app: '', capability: '' })
        fetchConsents()
      } else {
        const data = await response.json()
        setError(data.detail || 'Failed to grant consent')
      }
    } catch (err) {
      setError('Error granting consent')
    }
  }

  const revokeConsent = async (consent: Consent) => {
    setError('')
    setSuccess('')
    
    try {
      const response = await fetch(`http://10.1.1.74:8001/consent/user/${consent.user_id}/capability`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          user_id: consent.user_id,
          requesting_app_name: consent.requesting_app_name,
          destination_app_name: consent.destination_app_name,
          capability: consent.capability
        })
      })

      if (response.ok) {
        setSuccess('Consent revoked successfully')
        fetchConsents()
      } else {
        setError('Failed to revoke consent')
      }
    } catch (err) {
      setError('Error revoking consent')
    }
  }

  const clearAllConsents = async () => {
    if (!session?.user) return

    setError('')
    setSuccess('')
    
    if (!confirm('Are you sure you want to clear all consents? This action cannot be undone.')) {
      return
    }

    try {
      const response = await fetch(`http://10.1.1.74:8001/consent/user/${userId}`, {
        method: 'DELETE'
      })

      if (response.ok) {
        setSuccess('All consents cleared successfully')
        fetchConsents()
      } else {
        setError('Failed to clear all consents')
      }
    } catch (err) {
      setError('Error clearing consents')
    }
  }

  useEffect(() => {
    if (session?.user) {
      fetchConsents()
      fetchApplications()
    }
  }, [session, userId])

  if (!session) {
    return (
      <article>
        <p className="text-center">Please sign in to manage your consents</p>
      </article>
    )
  }

  if (loading) {
    return (
      <article aria-busy="true">
        <p className="text-center">Loading consents...</p>
      </article>
    )
  }

  return (
    <div>
      <article style={{ marginBottom: '2rem' }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <h2 style={{ margin: 0 }}>🔐 Your Consents</h2>
          <div style={{ display: 'flex', gap: '1rem' }}>
            <button
              onClick={() => setShowGrantForm(!showGrantForm)}
              className="btn-gradient-success"
              style={{ padding: '0.5rem 1rem' }}
            >
              {showGrantForm ? 'Cancel' : '+ Grant New Consent'}
            </button>
            {consents.length > 0 && (
              <button
                onClick={clearAllConsents}
                className="btn-gradient-danger"
                style={{ padding: '0.5rem 1rem' }}
              >
                Clear All
              </button>
            )}
          </div>
        </header>

        {error && (
          <div className="response-box response-error" style={{ marginBottom: '1rem' }}>
            {error}
          </div>
        )}

        {success && (
          <div className="response-box response-success" style={{ marginBottom: '1rem' }}>
            {success}
          </div>
        )}

        {showGrantForm && (
          <form onSubmit={grantConsent} style={{ marginBottom: '2rem', padding: '1.5rem', background: 'var(--pico-background-color)', borderRadius: '8px', border: '1px solid var(--pico-muted-border-color)' }}>
            <h4 style={{ marginBottom: '1rem' }}>Grant New Consent</h4>
            <div className="grid" style={{ gap: '1rem' }}>
              <div>
                <label htmlFor="requesting_app">
                  Requesting Application
                  <select
                    id="requesting_app"
                    value={grantForm.requesting_app}
                    onChange={(e) => setGrantForm({ ...grantForm, requesting_app: e.target.value })}
                    required
                  >
                    <option value="">Select application...</option>
                    {applications.map(app => (
                      <option key={app.id} value={app.name}>{app.name}</option>
                    ))}
                  </select>
                </label>
              </div>
              
              <div>
                <label htmlFor="destination_app">
                  Destination Application
                  <select
                    id="destination_app"
                    value={grantForm.destination_app}
                    onChange={(e) => setGrantForm({ ...grantForm, destination_app: e.target.value, capability: '' })}
                    required
                  >
                    <option value="">Select application...</option>
                    {applications.map(app => (
                      <option key={app.id} value={app.name}>{app.name}</option>
                    ))}
                  </select>
                </label>
              </div>

              <div>
                <label htmlFor="capability">
                  Capability
                  <select
                    id="capability"
                    value={grantForm.capability}
                    onChange={(e) => setGrantForm({ ...grantForm, capability: e.target.value })}
                    required
                    disabled={!grantForm.destination_app}
                  >
                    <option value="">Select capability...</option>
                    {grantForm.destination_app && applications
                      .find(app => app.name === grantForm.destination_app)
                      ?.capabilities.map(cap => (
                        <option key={cap} value={cap}>{cap}</option>
                      ))}
                  </select>
                </label>
              </div>
            </div>
            
            <button type="submit" className="btn-gradient-primary" style={{ marginTop: '1rem' }}>
              Grant Consent
            </button>
          </form>
        )}

        {consents.length === 0 ? (
          <p style={{ textAlign: 'center', color: 'var(--pico-muted-color)' }}>
            No consents granted yet. Grant a consent to allow applications to act on your behalf.
          </p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {consents.map((consent) => (
              <article key={consent.id} style={{ padding: '1.5rem', marginBottom: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start' }}>
                  <div>
                    <h4 style={{ margin: 0, marginBottom: '0.5rem', color: 'var(--pico-primary)' }}>
                      {consent.requesting_app_name} → {consent.destination_app_name}
                    </h4>
                    <p style={{ margin: 0, marginBottom: '0.25rem' }}>
                      <strong>Capability:</strong> <code>{consent.capability}</code>
                    </p>
                    <p style={{ margin: 0, fontSize: '0.875rem', color: 'var(--pico-muted-color)' }}>
                      Granted: {new Date(consent.granted_at).toLocaleString()}
                    </p>
                  </div>
                  <button
                    onClick={() => revokeConsent(consent)}
                    className="btn-gradient-danger"
                    style={{ padding: '0.5rem 1rem' }}
                  >
                    Revoke
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </article>
    </div>
  )
}