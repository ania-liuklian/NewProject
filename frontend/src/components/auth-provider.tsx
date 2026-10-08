import { useQueryClient } from '@tanstack/react-query'
import { Hub } from 'aws-amplify/utils'
import { signOut as cognitoSignOut } from 'aws-amplify/auth'
import { useEffect, useRef, useState, type ReactNode } from 'react'

import { AuthContext, authConfig, authConfigured, loadUser, type User } from '@/lib/auth'

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const [user, setUser] = useState<User | null | undefined>(authConfigured ? undefined : null)
  const hostedLogoutInProgress = useRef(false)

  useEffect(() => {
    if (!authConfigured) return
    let active = true
    const refresh = () => loadUser().then((next) => active && setUser(next))
    refresh()
    // Keeps the state in step with Cognito: the Google redirect, sign-out in another place
    // (e.g. a 401 from the API), or a refresh token that no longer works.
    const stop = Hub.listen('auth', ({ payload }) => {
      if (payload.event === 'signedIn' || payload.event === 'signInWithRedirect') refresh()
      if (
        (payload.event === 'signedOut' && !hostedLogoutInProgress.current) ||
        payload.event === 'tokenRefresh_failure'
      ) {
        setUser(null)
        // The next user must not see this user's cached meetings.
        queryClient.clear()
      }
    })
    return () => {
      active = false
      stop()
    }
  }, [queryClient])

  const signIn = (next: User) => setUser(next)
  const signOut = async () => {
    hostedLogoutInProgress.current = true
    // Clear Amplify's local tokens, then clear the Managed Login browser session too.
    // Keep the app on the current page until navigation, or /login can start a new
    // Managed Login redirect before the browser reaches Cognito's logout endpoint.
    try {
      await cognitoSignOut()
    } catch {
      // Continue to Cognito's logout endpoint even if local token cleanup failed.
    }
    queryClient.clear()

    if (authConfig.domain && authConfig.clientId) {
      const domain = authConfig.domain.startsWith('http')
        ? authConfig.domain
        : `https://${authConfig.domain}`
      const logoutUrl = new URL('/logout', domain)
      logoutUrl.searchParams.set('client_id', authConfig.clientId)
      logoutUrl.searchParams.set('logout_uri', `${window.location.origin}/login`)
      window.location.replace(logoutUrl.toString())
      return
    }

    hostedLogoutInProgress.current = false
    setUser(null)
  }

  return <AuthContext value={{ user, signIn, signOut }}>{children}</AuthContext>
}
