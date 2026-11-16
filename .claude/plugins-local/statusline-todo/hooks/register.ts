import type { EngineInterface as Engine, Register } from 'claude-code'

// Per-session todo list kept in ~/.cache/claude-todos/<session id>.txt, one item per line:
//   [ ] not done
//   [x] done
// The plugin only edits the file. statusline-segment.sh (next to this folder) draws it, called
// from ~/.claude/statusline.sh, so it appends to whatever else the status line prints.

type Item = { isDone: boolean; text: string }

const VERBS = ['add', 'done', 'undo', 'rm', 'remove', 'clear', 'list'] as const

async function todoPath($: Engine) {
  const home = (await $.env.get('HOME')) ?? ''
  const dir = (await $.env.get('XDG_CACHE_HOME')) || `${home}/.cache`
  return `${dir}/claude-todos/${await $.session.id()}.txt`
}

function parse(text: string): Item[] {
  return text
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => {
      const m = line.match(/^\[([ xX]?)\]\s*(.*)$/)
      return m ? { isDone: (m[1] ?? '').toLowerCase() === 'x', text: m[2] ?? '' } : { isDone: false, text: line }
    })
}

const serialize = (items: Item[]) => items.map(i => `[${i.isDone ? 'x' : ' '}] ${i.text}`).join('\n') + (items.length ? '\n' : '')

async function load($: Engine) {
  const path = await todoPath($)
  const text = await $.fs.read(path).catch(() => '')
  return { path, items: parse(typeof text === 'string' ? text : '') }
}

function render(items: Item[]) {
  if (!items.length) return 'Todo list is empty.'
  return items.map((i, n) => `${n + 1}. ${i.isDone ? '✔' : '☐'} ${i.text}`).join('\n')
}

// 1-based indices; out-of-range ones are reported, not fatal.
function pick(items: Item[], indices: number[]) {
  const ok = [...new Set(indices)].filter(n => Number.isInteger(n) && n >= 1 && n <= items.length)
  const bad = indices.filter(n => !ok.includes(n))
  return { ok, bad }
}

type Action = { action: string; items?: string[]; indices?: number[]; all?: boolean }

async function apply($: Engine, a: Action): Promise<{ text: string; isError?: boolean }> {
  const { path, items } = await load($)
  let note = ''
  let next = items

  switch (a.action) {
    case 'list':
      return { text: render(items) }
    case 'add': {
      const add = (a.items ?? []).map(s => s.trim()).filter(Boolean)
      if (!add.length) return { text: 'Nothing to add.', isError: true }
      next = [...items, ...add.map(text => ({ isDone: false, text }))]
      break
    }
    case 'done':
    case 'undo':
    case 'rm':
    case 'remove': {
      const { ok, bad } = pick(items, a.indices ?? [])
      if (!ok.length) return { text: `No such item${bad.length ? `: ${bad.join(', ')}` : ''}.\n${render(items)}`, isError: true }
      if (bad.length) note = `Skipped out-of-range: ${bad.join(', ')}\n`
      next =
        a.action === 'done' || a.action === 'undo'
          ? items.map((i, n) => (ok.includes(n + 1) ? { ...i, isDone: a.action === 'done' } : i))
          : items.filter((_, n) => !ok.includes(n + 1))
      break
    }
    case 'clear':
      next = a.all ? [] : items.filter(i => !i.isDone)
      break
    default:
      return { text: `Unknown action "${a.action}".`, isError: true }
  }

  await $.fs.write(path, serialize(next))
  return { text: note + render(next) }
}

const USAGE = [
  '/todo                 list',
  '/todo <text>          add an item (same as /todo add <text>)',
  '/todo add <text>      add an item; separate several with " ; "',
  '/todo done <n> [n…]   check off',
  '/todo undo <n> [n…]   uncheck',
  '/todo rm <n> [n…]     remove',
  '/todo clear [all]     remove checked items (or everything)',
].join('\n')

function parseArgs(raw: string): Action | null {
  const args = raw.trim()
  if (!args) return { action: 'list' }
  if (args === 'help' || args === '-h' || args === '--help') return null
  const [head = '', ...rest] = args.split(/\s+/)
  const verb = head.toLowerCase()
  const tail = args.slice(head.length).trim()
  if (!(VERBS as readonly string[]).includes(verb)) return { action: 'add', items: args.split(/\s+;\s+/) }
  if (verb === 'add') return { action: 'add', items: tail.split(/\s+;\s+/) }
  if (verb === 'clear') return { action: 'clear', all: rest[0]?.toLowerCase() === 'all' }
  if (verb === 'list') return { action: 'list' }
  return { action: verb, indices: rest.flatMap(s => s.split(',')).filter(Boolean).map(Number) }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'todo',
      description: 'Status-line todo list: add, done, undo, rm, clear',
      argumentHint: '[add|done|undo|rm|clear] …',
    })
    await $.tool.register({
      name: 'todo',
      description:
        "Edit the user's personal todo list shown in their status line (one per session). " +
        'Use only when the user asks about their todo list / status-line todos, not for your own task tracking. ' +
        'Actions: list; add (items: strings); done, undo, remove (indices: 1-based numbers as shown by list); ' +
        'clear (removes checked items, or everything with all: true). Returns the list after the change.',
      inputSchema: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['list', 'add', 'done', 'undo', 'remove', 'clear'] },
          items: { type: 'array', items: { type: 'string' } },
          indices: { type: 'array', items: { type: 'integer' } },
          all: { type: 'boolean' },
        },
        required: ['action'],
      },
    })
    return next(e)
  })

  on('command.run', { command: 'todo' }, async ($, e) => {
    const action = parseArgs(e.args)
    if (!action) return { text: USAGE }
    const { text } = await apply($, action)
    return { text }
  })

  on('tool.call', { tool: 'mcp__statusline-todo__todo' }, async ($, e) => {
    const { text, isError } = await apply($, e as unknown as Action)
    return isError ? { deny: text } : { result: text }
  })
}
