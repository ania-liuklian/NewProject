import { useCallback, useEffect, useRef, useState } from 'react'
import { signInWithRedirect } from 'aws-amplify/auth'

import { AuthLayout, AuthNotConfigured } from '@/components/auth-layout'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { authConfigured } from '@/lib/auth'

export function LoginPage() {
  const [error, setError] = useState('')
  const redirectStarted = useRef(false)

  const startManagedLogin = useCallback(() => {
    if (!authConfigured || redirectStarted.current) return
    redirectStarted.current = true
    setError('')
    void signInWithRedirect().catch((reason: unknown) => {
      redirectStarted.current = false
      setError(reason instanceof Error ? reason.message : 'Could not open Cognito sign-in.')
    })
  }, [])

  // The Cognito page provides email/password sign-in, self sign-up, and Google.
  useEffect(() => {
    startManagedLogin()
  }, [startManagedLogin])

  return (
    <AuthLayout
      title="Sign in"
      subtitle="Continue securely with Amazon Cognito."
      footer={<span>Redirecting to secure sign-in…</span>}
    >
      {!authConfigured ? (
        <AuthNotConfigured />
      ) : (
        <>
          {error && (
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
          <Button className="w-full" onClick={startManagedLogin}>
            Continue to sign in
          </Button>
        </>
      )}
    </AuthLayout>
  )
}
