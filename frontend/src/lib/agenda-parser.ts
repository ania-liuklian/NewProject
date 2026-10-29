import type { AgendaSuggestion, ParsedAgenda } from '@/lib/api'

const NUMBERED_ITEM = /(?:^|\s)(\d+)[.)]\s*/g
const MINUTES = /\b(\d+)\s*(?:min(?:ute)?s?|хв(?:илин(?:и)?)?)\b/i
const OWNER = /(?:^|\s)[—–-]\s*([^,;]+?)(?=,|$)/
const ACTION_CUE = /\b(?:action|todo|to-do|by|before|до|збирає|підготувати|надіслати|prepare|send|follow.?up)\b/i

function clean(value: string): string {
  return value.replace(/^[\s,.;:—–-]+|[\s,.;:—–-]+$/g, '').trim()
}

function parseTopic(raw: string): ParsedAgenda['items'][number] {
  const owner = raw.match(OWNER)?.[1]
  const minutesMatch = raw.match(MINUTES)
  const topic = clean(raw.replace(OWNER, ' ').replace(MINUTES, ' '))
  return {
    topic,
    owner: owner ? clean(owner) : null,
    minutes: minutesMatch ? Number(minutesMatch[1]) : null,
  }
}

/** A small deterministic parser that runs locally in the browser and makes no model calls. */
export function parseAgendaLocally(text: string): AgendaSuggestion {
  const lines = text.split(/\r?\n/).map(clean).filter(Boolean)
  const numberedItems: string[] = []
  const otherLines: string[] = []

  for (const line of lines) {
    NUMBERED_ITEM.lastIndex = 0
    const markers = [...line.matchAll(NUMBERED_ITEM)]
    if (!markers.length) {
      const bullet = line.match(/^[-*•]\s+(.+)$/)
      if (bullet) numberedItems.push(bullet[1])
      else otherLines.push(line)
      continue
    }
    const preface = clean(line.slice(0, markers[0].index ?? 0))
    if (preface) otherLines.push(preface)
    for (let i = 0; i < markers.length; i += 1) {
      const start = (markers[i].index ?? 0) + markers[i][0].length
      const end = i + 1 < markers.length ? (markers[i + 1].index ?? line.length) : line.length
      const item = clean(line.slice(start, end))
      if (item) numberedItems.push(item)
    }
  }

  const agendaItems = numberedItems.map(parseTopic).filter((item) => item.topic.length > 0)
  const actions = otherLines
    .filter((line) => ACTION_CUE.test(line))
    .map((line) => {
      const ownerMatch = line.match(/^([\p{L}][\p{L}'’-]*)\s+(?=(?:до|by|before)\b)/iu)
      return {
        task: clean(line.replace(ownerMatch?.[0] ?? '', '')),
        owner: ownerMatch?.[1] ?? null,
        due: null,
      }
    })
    .filter((item) => item.task.length > 0)

  if (agendaItems.length === 0 && actions.length === 0) {
    throw new Error('Could not find numbered agenda items. You can still type the agenda manually.')
  }

  const titleSource = otherLines.find((line) => !ACTION_CUE.test(line))
  const intro = titleSource ?? ''
  const durationMatch = intro.match(MINUTES)
  const title = clean(intro.replace(/\b(?:пн|вт|ср|чт|пт|сб|нд|mon|tue|wed|thu|fri|sat|sun)\b\s*/i, '')
    .replace(/\b\d{1,2}:\d{2}\b/, '').replace(MINUTES, ''))
  const agenda: ParsedAgenda = {
    title: title || null,
    starts_at: null,
    duration_minutes: durationMatch ? Number(durationMatch[1]) : null,
    items: agendaItems,
    action_items: actions,
    language: /[іїєґ]/i.test(text) ? 'uk' : /[а-яё]/i.test(text) ? 'ru' : 'en',
  }

  return { agenda, model: 'Local rules', prompt_version: 'local-rules-v1' }
}
