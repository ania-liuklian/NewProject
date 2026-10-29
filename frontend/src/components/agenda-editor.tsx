import { useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { api, type AgendaSuggestion, type Meeting, type ParsedAgenda } from '@/lib/api'
import { parseAgendaLocally } from '@/lib/agenda-parser'
import { meetingsKey } from '@/hooks/queries'

export function AgendaEditor({ meeting }: { meeting: Meeting }) {
  const queryClient = useQueryClient()
  const [source, setSource] = useState('')
  const [suggestion, setSuggestion] = useState<AgendaSuggestion | null>(null)
  const [agenda, setAgenda] = useState<ParsedAgenda>(meeting.agenda ?? {
    title: null, starts_at: null, duration_minutes: null, items: [], action_items: [], language: 'en',
  })
  const [edited, setEdited] = useState<Set<string>>(new Set())
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const controller = useRef<AbortController | null>(null)

  async function parse() {
    if (!source.trim()) return
    controller.current = new AbortController()
    setBusy(true)
    setError('')
    try {
      const result = await api.parseAgenda(source, controller.current.signal)
      setSuggestion(result); setAgenda(result.agenda); setEdited(new Set())
    } catch (cause) {
      if (cause instanceof DOMException && cause.name === 'AbortError') return
      setError(cause instanceof Error ? cause.message : 'Could not parse this agenda.')
    } finally { setBusy(false) }
  }

  function parseLocally() {
    try {
      const result = parseAgendaLocally(source)
      setSuggestion(result); setAgenda(result.agenda); setEdited(new Set()); setError('')
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not parse this agenda.')
    }
  }

  async function save() {
    try {
      await api.saveAgenda(meeting.id, agenda, suggestion ?? undefined)
      await queryClient.invalidateQueries({ queryKey: meetingsKey })
      toast.success('Agenda saved')
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save agenda.') }
  }

  function changeItem(index: number, key: 'topic' | 'owner' | 'minutes', value: string) {
    setEdited((current) => new Set(current).add(`item-${index}-${key}`))
    setAgenda((current) => ({ ...current, items: current.items.map((item, i) => i === index
      ? { ...item, [key]: key === 'minutes' ? (value ? Number(value) : null) : (value || null) }
      : item) }))
  }

  return <section className="flex flex-col gap-3 border-t pt-4">
    <h3 className="text-lg">Agenda</h3>
    {meeting.agenda && !suggestion && <p className="text-sm text-muted-foreground">Saved agenda</p>}
    <Textarea rows={4} aria-label="Paste an agenda" placeholder="Paste an email, chat, or notes…"
      value={source} onChange={(event) => setSource(event.target.value)} maxLength={10000} />
    <div className="flex gap-2">
      <Button type="button" variant="outline" disabled={busy || !source.trim()} onClick={parse}>
        {busy ? 'Parsing with Cloudflare AI…' : 'Parse agenda'}
      </Button>
      {busy && <Button type="button" variant="ghost" onClick={() => controller.current?.abort()}>Cancel</Button>}
    </div>
    {busy && <p role="status">Cloudflare Workers AI is preparing a suggestion…</p>}
    <p className="text-xs text-muted-foreground">Cloudflare Free includes 10,000 Neurons per day; requests pause at the limit. Review the suggestion before saving.</p>
    {error && <Button type="button" variant="ghost" onClick={parseLocally}>Use local rules instead</Button>}
    {error && <p role="alert" className="text-sm text-destructive">{error} You can still type an agenda below.</p>}
    {suggestion && <p className="text-sm text-muted-foreground">Suggestion ready; review and edit before saving.</p>}
    <label className="flex flex-col gap-1 text-sm">Agenda title {suggestion && !edited.has('title') && <small>Suggested</small>}
      <input className="rounded-md border bg-background px-3 py-2" value={agenda.title ?? ''}
        onChange={(e) => { setEdited((current) => new Set(current).add('title')); setAgenda({ ...agenda, title: e.target.value || null }) }} />
    </label>
    <div className="grid grid-cols-2 gap-2">
      <label className="flex flex-col gap-1 text-sm">Meeting time (ISO 8601 with timezone)
        <input className="rounded-md border bg-background px-3 py-2" value={agenda.starts_at ?? ''}
          onChange={(event) => { setEdited((current) => new Set(current).add('starts_at')); setAgenda({ ...agenda, starts_at: event.target.value || null }) }} />
      </label>
      <label className="flex flex-col gap-1 text-sm">Duration in minutes
        <input className="rounded-md border bg-background px-3 py-2" type="number" min={1} max={600}
          value={agenda.duration_minutes ?? ''}
          onChange={(event) => { setEdited((current) => new Set(current).add('duration_minutes')); setAgenda({ ...agenda, duration_minutes: event.target.value ? Number(event.target.value) : null }) }} />
      </label>
    </div>
    <div className="flex gap-2">
      <Button type="button" variant="ghost" onClick={() => setAgenda({
        ...agenda, items: [...agenda.items, { topic: '', owner: null, minutes: null }],
      })}>Add agenda item</Button>
      <Button type="button" variant="ghost" onClick={() => setAgenda({
        ...agenda, action_items: [...agenda.action_items, { task: '', owner: null, due: null }],
      })}>Add action item</Button>
    </div>
    {agenda.items.map((item, i) => <div key={i} className="grid grid-cols-3 gap-2">
      <label className="col-span-3 text-sm">Topic {i + 1} {suggestion && !edited.has(`item-${i}-topic`) && <small>Suggested</small>}<input className="mt-1 w-full rounded-md border bg-background px-3 py-2"
        value={item.topic} onChange={(e) => changeItem(i, 'topic', e.target.value)} /></label>
      <input aria-label={`Owner ${i + 1}`} placeholder="Owner" className="rounded-md border bg-background px-2 py-2"
        value={item.owner ?? ''} onChange={(e) => changeItem(i, 'owner', e.target.value)} />
      <input aria-label={`Minutes ${i + 1}`} type="number" min={1} max={480} placeholder="Minutes"
        className="rounded-md border bg-background px-2 py-2" value={item.minutes ?? ''}
        onChange={(e) => changeItem(i, 'minutes', e.target.value)} />
    </div>)}
    {agenda.action_items.map((item, i) => <div key={`action-${i}`} className="grid gap-2 text-sm">
      <strong>Action item {i + 1} {suggestion && !edited.has(`action-${i}`) && <small>Suggested</small>}</strong>
      <input aria-label={`Action item ${i + 1}`} className="rounded-md border bg-background px-3 py-2"
        value={item.task} onChange={(e) => { setEdited((current) => new Set(current).add(`action-${i}`)); setAgenda({ ...agenda, action_items: agenda.action_items.map((value, index) => index === i ? { ...value, task: e.target.value } : value) }) }} />
      <input aria-label={`Action owner ${i + 1}`} placeholder="Owner" className="rounded-md border bg-background px-3 py-2"
        value={item.owner ?? ''} onChange={(e) => setAgenda({ ...agenda, action_items: agenda.action_items.map((value, index) => index === i ? { ...value, owner: e.target.value || null } : value) })} />
    </div>)}
    {suggestion && <p className="text-xs text-muted-foreground">Suggested labels disappear as you edit each field.</p>}
    {(agenda.items.length > 0 || agenda.action_items.length > 0) && <Button type="button" onClick={save}>Save agenda</Button>}
  </section>
}
