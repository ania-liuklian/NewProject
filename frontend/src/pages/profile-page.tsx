import { ArrowLeftIcon } from 'lucide-react'
import { useState, type FormEvent, type ReactNode } from 'react'
import { Link } from 'react-router'

import { PasswordInput } from '@/components/auth-layout'
import { Button } from '@/components/ui/button'
import { Field, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  useAuth,
  useChangeEmail,
  useChangePassword,
  useConfirmEmail,
  useResendEmailCode,
  useUpdateName,
} from '@/lib/auth'

function ProfileField({ name, label, children }: { name: string; label: string; children: ReactNode }) {
  return (
    <Field>
      <FieldLabel htmlFor={name}>{label}</FieldLabel>
      {children}
    </Field>
  )
}

function formValues(event: FormEvent<HTMLFormElement>) {
  event.preventDefault()
  return new FormData(event.currentTarget)
}

function ProfileForms({ name }: { name: string }) {
  const updateName = useUpdateName()
  const changeEmail = useChangeEmail()
  const confirmEmail = useConfirmEmail()
  const resend = useResendEmailCode()
  const changePassword = useChangePassword()
  const [pendingEmail, setPendingEmail] = useState<string | null>(null)
  const [emailNotice, setEmailNotice] = useState('')
  const [passwordError, setPasswordError] = useState('')
  const emailError = changeEmail.error ?? confirmEmail.error ?? resend.error
  const emailBusy = changeEmail.isPending || confirmEmail.isPending || resend.isPending
  const card = 'space-y-4 rounded-2xl bg-card p-5'

  return (
    <>
      <form className={card} onSubmit={(event) => {
        const name = String(formValues(event).get('name')).trim()
        if (name) updateName.mutate(name)
      }}>
        <h2 className="text-xl">Name</h2>
        <ProfileField name="name" label="Display name">
          <Input id="name" name="name" defaultValue={name} autoComplete="name" required />
        </ProfileField>
        {updateName.error && <p role="alert">{updateName.error.message}</p>}
        {updateName.isSuccess && <p role="status">Name updated.</p>}
        <Button disabled={updateName.isPending}>Save name</Button>
      </form>

      <section className={card} aria-labelledby="profile-email-heading">
        <h2 id="profile-email-heading" className="text-xl">Email</h2>
        {pendingEmail ? (
          <form className="space-y-4" onSubmit={(event) => {
            const code = String(formValues(event).get('code')).trim()
            resend.reset()
            confirmEmail.mutate(code, { onSuccess: () => {
              setPendingEmail(null)
              setEmailNotice('Email updated.')
            } })
          }}>
            <p>Enter the verification code sent to {pendingEmail}.</p>
            <ProfileField name="code" label="Verification code">
              <Input id="code" name="code" autoComplete="one-time-code" inputMode="numeric" required />
            </ProfileField>
            <div className="flex flex-wrap gap-2">
              <Button disabled={emailBusy}>Verify email</Button>
              <Button type="button" variant="outline" disabled={emailBusy} onClick={() => {
                confirmEmail.reset()
                resend.mutate(undefined, { onSuccess: () => setEmailNotice('A new code was sent.') })
              }}>Send a new code</Button>
              <Button type="button" variant="ghost" disabled={emailBusy} onClick={() => {
                confirmEmail.reset()
                resend.reset()
                setEmailNotice('')
                setPendingEmail(null)
              }}>Cancel</Button>
            </div>
          </form>
        ) : (
          <form className="space-y-4" onSubmit={(event) => {
            const email = String(formValues(event).get('email')).trim()
            setEmailNotice('')
            changeEmail.mutate(email, { onSuccess: () => setPendingEmail(email) })
          }}>
            <ProfileField name="email" label="New email">
              <Input id="email" name="email" type="email" autoComplete="email" required />
            </ProfileField>
            <Button disabled={emailBusy}>Send verification code</Button>
          </form>
        )}
        {emailError && <p role="alert">{emailError.message}</p>}
        {emailNotice && <p role="status">{emailNotice}</p>}
      </section>

      <form className={card} onSubmit={(event) => {
        const form = event.currentTarget
        const values = formValues(event)
        const newPassword = String(values.get('newPassword'))
        changePassword.reset()
        if (newPassword !== values.get('confirmation')) {
          setPasswordError('Passwords do not match.')
          return
        }
        setPasswordError('')
        changePassword.mutate(
          { currentPassword: String(values.get('currentPassword')), newPassword },
          { onSuccess: () => form.reset() },
        )
      }}>
        <h2 className="text-xl">Password</h2>
        <ProfileField name="currentPassword" label="Current password">
          <PasswordInput id="currentPassword" name="currentPassword" autoComplete="current-password" required />
        </ProfileField>
        <ProfileField name="newPassword" label="New password">
          <PasswordInput id="newPassword" name="newPassword" autoComplete="new-password" minLength={8} required />
        </ProfileField>
        <ProfileField name="confirmation" label="Confirm new password">
          <PasswordInput id="confirmation" name="confirmation" autoComplete="new-password" minLength={8} required />
        </ProfileField>
        {passwordError && <p role="alert">{passwordError}</p>}
        {changePassword.error && <p role="alert">{changePassword.error.message}</p>}
        {changePassword.isSuccess && <p role="status">Password updated.</p>}
        <Button disabled={changePassword.isPending}>Change password</Button>
      </form>
    </>
  )
}

export function ProfilePage() {
  const { user } = useAuth()
  if (!user) return null

  return (
    <main className="mx-auto flex max-w-xl flex-col gap-4 px-4 py-6">
      <Link to="/home" className="flex w-fit items-center gap-2 hover:underline">
        <ArrowLeftIcon className="size-4" aria-hidden />
        Meetings
      </Link>
      <header className="flex items-center gap-4">
        <span className="grid size-12 shrink-0 place-items-center rounded-full bg-secondary text-lg font-semibold" aria-hidden>
          {user.name.charAt(0).toUpperCase()}
        </span>
        <div>
          <h1 className="text-3xl">{user.name}</h1>
          <p className="text-muted-foreground">{user.email}</p>
        </div>
      </header>
      {user.provider === 'google'
        ? <p className="rounded-2xl bg-card p-5">Manage your name, email, and password in your Google Account.</p>
        : <ProfileForms name={user.name} />}
    </main>
  )
}
