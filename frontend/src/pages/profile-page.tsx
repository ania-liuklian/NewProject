import { zodResolver } from '@hookform/resolvers/zod'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { Link } from 'react-router'
import { z } from 'zod'

import { AuthLayout } from '@/components/auth-layout'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { useAuth, useUpdateName } from '@/lib/auth'

const profileSchema = z.object({ name: z.string().trim().min(1, 'Enter your name').max(100) })
type ProfileValues = z.infer<typeof profileSchema>

export function ProfilePage() {
  const { user } = useAuth()
  const updateName = useUpdateName()
  const form = useForm<ProfileValues>({
    resolver: zodResolver(profileSchema),
    defaultValues: { name: user?.name ?? '' },
  })

  useEffect(() => {
    if (user) form.reset({ name: user.name })
  }, [form, user])

  const onSubmit = form.handleSubmit(({ name }) =>
    updateName.mutate(name.trim(), {
      onSuccess: () => form.reset({ name: name.trim() }),
      onError: (error) => form.setError('root', { message: error.message }),
    }),
  )

  return (
    <AuthLayout
      title="Your profile"
      subtitle="Manage the name shown with your account."
      footer={
        <Link to="/home" className="font-semibold text-hover underline-offset-4 hover:underline">
          Back to meetings
        </Link>
      }
    >
      {user?.provider === 'google' ? (
        <Alert>
          <AlertDescription>
            Your name is managed by Google and is updated when you sign in.
          </AlertDescription>
        </Alert>
      ) : (
        <form onSubmit={onSubmit} noValidate>
          <FieldGroup className="gap-4">
            <div className="text-sm text-muted-foreground">{user?.email}</div>
            <Controller
              name="name"
              control={form.control}
              render={({ field, fieldState }) => (
                <Field data-invalid={fieldState.invalid}>
                  <FieldLabel htmlFor="profile-name">Name</FieldLabel>
                  <Input
                    id="profile-name"
                    autoComplete="name"
                    aria-invalid={fieldState.invalid}
                    {...field}
                  />
                  <FieldError errors={[fieldState.error]} />
                </Field>
              )}
            />
            {form.formState.errors.root && (
              <FieldError>{form.formState.errors.root.message}</FieldError>
            )}
            {updateName.isSuccess && (
              <p className="text-sm text-muted-foreground" role="status">
                Name updated.
              </p>
            )}
            <Button type="submit" disabled={updateName.isPending || !form.formState.isDirty}>
              {updateName.isPending ? 'Saving...' : 'Save changes'}
            </Button>
          </FieldGroup>
        </form>
      )}
    </AuthLayout>
  )
}
