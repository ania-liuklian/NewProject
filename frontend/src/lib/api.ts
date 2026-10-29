import { signOut } from 'aws-amplify/auth'

import { getIdToken } from '@/lib/auth'

export type Participant = {
  id: string
  name: string
  email: string
}

export type Meeting = {
  id: string
  title: string
  description: string
  agenda: ParsedAgenda | null
  starts_at: string
  ends_at: string
  place: string
  participants: Participant[]
  created_at: string
}

export type ParsedAgenda = {
  title: string | null
  starts_at: string | null
  duration_minutes: number | null
  items: { topic: string; owner: string | null; minutes: number | null }[]
  action_items: { task: string; owner: string | null; due: string | null }[]
  language: string
}

export type AgendaSuggestion = { agenda: ParsedAgenda; model: string; prompt_version: string }

export type MeetingCreate = {
  title: string
  description: string
  starts_at: string
  ends_at: string
  place: string
  participant_ids: string[]
}

export type ParticipantCreate = {
  name: string
  email: string
}

export class ApiError extends Error {
  readonly status: number

  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

// Backend origin, set at build time for AWS (the Lambda function URL). Empty locally,
// where the Vite dev server or nginx proxies /api to the backend.
const API_URL = (import.meta.env.VITE_API_URL ?? '').replace(/\/+$/, '')
const PARSER_URL = (import.meta.env.VITE_PARSER_URL ?? '').replace(/\/+$/, '')

type ValidationIssue = { loc?: (string | number)[]; msg: string }

function errorMessage(detail: unknown, fallback: string): string {
  if (typeof detail === 'string') return detail
  if (Array.isArray(detail)) {
    return (detail as ValidationIssue[])
      .map((issue) => {
        const field = issue.loc?.filter((part) => part !== 'body').join('.')
        const msg = issue.msg.replace(/^Value error, /, '')
        return field ? `${field}: ${msg}` : msg
      })
      .join('; ')
  }
  return fallback
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = await getIdToken()
  const response = await fetch(`${API_URL}/api${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...init?.headers,
    },
  })

  // The session is gone (revoked, or the refresh token expired): sign out, which sends the
  // user back to the login page (see AuthProvider).
  if (response.status === 401) await signOut().catch(() => undefined)

  if (!response.ok) {
    let detail: unknown
    try {
      detail = (await response.json()).detail
    } catch {
      // body was not JSON
    }
    throw new ApiError(response.status, errorMessage(detail, response.statusText))
  }

  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}

export const api = {
  listMeetings: () => request<Meeting[]>('/meetings'),
  createMeeting: (data: MeetingCreate) =>
    request<Meeting>('/meetings', { method: 'POST', body: JSON.stringify(data) }),
  updateMeeting: ({ id, ...data }: MeetingCreate & { id: string }) =>
    request<Meeting>(`/meetings/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteMeeting: (id: string) => request<void>(`/meetings/${id}`, { method: 'DELETE' }),
  parseAgenda: async (text: string, signal: AbortSignal): Promise<AgendaSuggestion> => {
    if (!PARSER_URL) throw new ApiError(503, 'Agenda parser URL is not configured.')
    const token = await getIdToken()
    const todayParts = new Intl.DateTimeFormat('en', {
      year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(new Date())
    const today = `${todayParts.find((part) => part.type === 'year')?.value}-${todayParts.find((part) => part.type === 'month')?.value}-${todayParts.find((part) => part.type === 'day')?.value}`
    const response = await fetch(PARSER_URL, {
      method: 'POST', signal,
      headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
      body: JSON.stringify({ text, today, tz: Intl.DateTimeFormat().resolvedOptions().timeZone }),
    })
    if (!response.ok) {
      const body = await response.json().catch(() => ({})) as { error?: string }
      throw new ApiError(response.status, body.error ?? response.statusText)
    }
    return response.json() as Promise<AgendaSuggestion>
  },
  saveAgenda: (id: string, agenda: ParsedAgenda, parser_suggestion?: AgendaSuggestion) =>
    request<Meeting>(`/meetings/${id}/agenda`, {
      method: 'PUT', body: JSON.stringify({ agenda, parser_suggestion }),
    }),
  listParticipants: () => request<Participant[]>('/participants'),
  createParticipant: (data: ParticipantCreate) =>
    request<Participant>('/participants', { method: 'POST', body: JSON.stringify(data) }),
}
