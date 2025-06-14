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

export function UserConsent() {
  const { data: session } = useSession()
  const [consents, setConsents] = useState<Consent[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const fetchConsents = async () => {
    if (!session?.user) return

    try {
      const userId = session.user.email || 'unknown'
      const response = await fetch(`http://localhost:8001/consent/user/${userId}`)
      if (response.ok) {
        const data = await response.json()
        setConsents(data)
      } else {
        setError('Failed to fetch consents')
      }
    } catch (err) {
      setError('Error fetching consents')
    } finally {
      setLoading(false)
    }
  }

  const revokeConsent = async (consent: Consent) => {
    try {
      const response = await fetch(`http://localhost:8001/consent/user/${consent.user_id}/capability`, {
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

    const userId = session.user.email || 'unknown'
    try {
      const response = await fetch(`http://localhost:8001/consent/user/${userId}`, {
        method: 'DELETE'
      })

      if (response.ok) {
        fetchConsents()
      } else {
        setError('Failed to clear all consents')
      }
    } catch (err) {
      setError('Error clearing consents')
    }
  }

  useEffect(() => {
    fetchConsents()
  }, [session])

  if (loading) {
    return <div className="p-4">Loading consents...</div>
  }

  return (
    <div className="p-6 bg-white rounded-lg shadow">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold">User Consents</h2>
        {consents.length > 0 && (
          <button
            onClick={clearAllConsents}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium rounded-md transition duration-200"
          >
            Clear All Consents
          </button>
        )}
      </div>

      {error && (
        <div className="mb-4 p-4 bg-red-100 text-red-800 rounded">
          {error}
        </div>
      )}

      {consents.length === 0 ? (
        <p className="text-gray-600">No consents granted yet</p>
      ) : (
        <div className="space-y-4">
          {consents.map((consent) => (
            <div key={consent.id} className="border rounded-lg p-4 flex justify-between items-center">
              <div>
                <p className="font-medium">
                  {consent.requesting_app_name} → {consent.destination_app_name}
                </p>
                <p className="text-sm text-gray-600">
                  Capability: <span className="font-mono">{consent.capability}</span>
                </p>
                <p className="text-xs text-gray-500">
                  Granted: {new Date(consent.granted_at).toLocaleString()}
                </p>
              </div>
              <button
                onClick={() => revokeConsent(consent)}
                className="px-3 py-1 bg-red-500 hover:bg-red-600 text-white text-sm rounded transition duration-200"
              >
                Revoke
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}