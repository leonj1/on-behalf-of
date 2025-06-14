'use client'

import { useSession, signIn, signOut } from 'next-auth/react'
import { useState } from 'react'

export default function Home() {
  const { data: session, status } = useSession()
  const [helloMessage, setHelloMessage] = useState<string>('')
  const [withdrawMessage, setWithdrawMessage] = useState<string>('')
  const [error, setError] = useState<string>('')

  const callHelloService = async () => {
    try {
      const response = await fetch('http://localhost:8003/hello')
      const data = await response.text()
      setHelloMessage(data)
      setError('')
    } catch (err) {
      setError('Failed to call hello service')
    }
  }

  const callBankingService = async () => {
    if (!session?.accessToken) {
      setError('No access token available')
      return
    }

    try {
      const response = await fetch('http://localhost:8004/withdraw', {
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
        setError(`Banking service error: ${errorData.detail || response.statusText}`)
        setWithdrawMessage('')
      }
    } catch (err) {
      setError('Failed to call banking service')
      setWithdrawMessage('')
    }
  }

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-lg">Loading...</p>
      </div>
    )
  }

  if (!session) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-gray-50">
        <div className="max-w-md w-full space-y-8">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-gray-900">On-Behalf-Of Demo</h1>
            <p className="mt-2 text-gray-600">Please sign in with Google via Keycloak</p>
          </div>
          <button
            onClick={() => signIn('keycloak')}
            className="w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-md transition duration-200"
          >
            Sign in with Google
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto p-8">
        <div className="bg-white shadow rounded-lg p-6">
          <div className="flex justify-between items-center mb-6">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Welcome, {session.user?.name || session.user?.email}</h1>
              <p className="text-gray-600">You are successfully authenticated</p>
            </div>
            <button
              onClick={() => signOut()}
              className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium rounded-md transition duration-200"
            >
              Sign out
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
            <div className="bg-gray-50 p-6 rounded-lg">
              <h2 className="text-lg font-semibold mb-4">Hello Service (Unprotected)</h2>
              <button
                onClick={callHelloService}
                className="w-full py-2 px-4 bg-green-600 hover:bg-green-700 text-white font-medium rounded-md transition duration-200"
              >
                Say Hello
              </button>
              {helloMessage && (
                <div className="mt-4 p-4 bg-green-100 text-green-800 rounded">
                  {helloMessage}
                </div>
              )}
            </div>

            <div className="bg-gray-50 p-6 rounded-lg">
              <h2 className="text-lg font-semibold mb-4">Banking Service (Protected)</h2>
              <button
                onClick={callBankingService}
                className="w-full py-2 px-4 bg-purple-600 hover:bg-purple-700 text-white font-medium rounded-md transition duration-200"
              >
                Empty Bank Account
              </button>
              {withdrawMessage && (
                <pre className="mt-4 p-4 bg-purple-100 text-purple-800 rounded text-sm overflow-auto">
                  {withdrawMessage}
                </pre>
              )}
            </div>
          </div>

          {error && (
            <div className="mt-6 p-4 bg-red-100 text-red-800 rounded">
              {error}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}