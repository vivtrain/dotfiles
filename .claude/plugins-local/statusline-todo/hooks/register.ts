import type { EngineInterface as Engine, Register } from 'claude-code'

// Per-session todo list kept in ~/.cache/claude-todos/<session id>.txt, one item per line:
//   [ ] open      󰄱
//   [x] done      󰄵 green
//   [!] failed    󰅘 red   (blocked, rejected, didn't work)
//   [~] partial   󰛲 yellow (in progress, waiting, half done)
// The plugin only edits the file. statusline-segment.sh (next to this folder) draws it, called
// from ~/.claude/statusline.sh, so it appends to whatever else the status line prints.

type State = ' ' | 'x' | '!' | '~'
type Item = { state: State; text: string }

const GLYPH: Record<State, string> = { ' ': '󰄱', x: '󰄵', '!': '󰅘', '~': '󰛲' }
// action -> state it sets
const MARK: Record<string, State> = { done: 'x', fail: '!', wip: '~', undo: ' ' }

const VERBS = ['add', 'edit', 'move', 'mv', 'done', 'fail', 'wip', 'undo', 'rm', 'remove', 'clear', 'list'] as const

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
      const m = line.match(/^\[([ xX!~]?)\]\s*(.*)$/)
      const c = (m?.[1] ?? ' ').toLowerCase() || ' '
      return m ? { state: c as State, text: m[2] ?? '' } : { state: ' ' as State, text: line }
    })
}

const serialize = (items: Item[]) => items.map(i => `[${i.state}] ${i.text}`).join('\n') + (items.length ? '\n' : '')

async function load($: Engine) {
  const path = await todoPath($)
  const text = await $.fs.read(path).catch(() => '')
  return { path, items: parse(typeof text === 'string' ? text : '') }
}

function render(items: Item[]) {
  if (!items.length) return 'Todo list is empty.'
  return items.map((i, n) => `${n + 1}. ${GLYPH[i.state]} ${i.text}`).join('\n')
}

// 1-based indices; out-of-range ones are reported, not fatal.
function pick(items: Item[], indices: number[]) {
  const ok = [...new Set(indices)].filter(n => Number.isInteger(n) && n >= 1 && n <= items.length)
  const bad = indices.filter(n => !ok.includes(n))
  return { ok, bad }
}

type Action = { action: string; items?: string[]; indices?: number[]; to?: number; all?: boolean }

// 1-based insert position -> 0-based, clamped; anything not a number appends.
const slot = (to: number | undefined, len: number) =>
  Number.isInteger(to) ? Math.min(Math.max(to! - 1, 0), len) : len

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
      const at = slot(a.to, items.length)
      next = [...items.slice(0, at), ...add.map(text => ({ state: ' ' as State, text })), ...items.slice(at)]
      break
    }
    case 'edit': {
      // indices[k] gets items[k] as its new text; state and position stay.
      const idx = a.indices ?? []
      const texts = (a.items ?? []).map(s => s.trim())
      if (!idx.length || idx.length !== texts.length || texts.some(t => !t))
        return { text: 'edit takes indices and items of the same length, one new text per index.', isError: true }
      const { bad } = pick(items, idx)
      if (bad.length) return { text: `No such item: ${bad.join(', ')}.\n${render(items)}`, isError: true }
      next = items.map((i, n) => {
        const k = idx.lastIndexOf(n + 1)
        return k < 0 ? i : { ...i, text: texts[k]! }
      })
      break
    }
    case 'mv':
    case 'move': {
      // The picked items, in list order, go to position `to` of the result, keeping their states.
      const { ok, bad } = pick(items, a.indices ?? [])
      if (!ok.length || !Number.isInteger(a.to))
        return { text: `move takes indices and to (1-based position).${bad.length ? ` No such item: ${bad.join(', ')}.` : ''}\n${render(items)}`, isError: true }
      if (bad.length) note = `Skipped out-of-range: ${bad.join(', ')}\n`
      const moving = items.filter((_, n) => ok.includes(n + 1))
      const rest = items.filter((_, n) => !ok.includes(n + 1))
      const at = slot(a.to, rest.length)
      next = [...rest.slice(0, at), ...moving, ...rest.slice(at)]
      break
    }
    case 'done':
    case 'fail':
    case 'wip':
    case 'undo':
    case 'rm':
    case 'remove': {
      const { ok, bad } = pick(items, a.indices ?? [])
      if (!ok.length) return { text: `No such item${bad.length ? `: ${bad.join(', ')}` : ''}.\n${render(items)}`, isError: true }
      if (bad.length) note = `Skipped out-of-range: ${bad.join(', ')}\n`
      next =
        a.action in MARK
          ? items.map((i, n) => (ok.includes(n + 1) ? { ...i, state: MARK[a.action]! } : i))
          : items.filter((_, n) => !ok.includes(n + 1))
      break
    }
    case 'clear':
      next = a.all ? [] : items.filter(i => i.state !== 'x')
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
  '/todo edit <n> <text> replace item n\'s text, keeping its state and place',
  '/todo mv <n> [n…] <to> move items so the first lands at position <to>',
  '/todo done <n> [n…]   check off (green 󰄵)',
  '/todo fail <n> [n…]   mark failed (red 󰅘)',
  '/todo wip <n> [n…]    mark partial / in progress (yellow 󰛲)',
  '/todo undo <n> [n…]   back to open 󰄱',
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
  if (verb === 'edit') return { action: 'edit', indices: [Number(rest[0])], items: [tail.slice((rest[0] ?? '').length).trim()] }
  if (verb === 'move' || verb === 'mv') {
    const nums = rest.flatMap(s => s.split(',')).filter(Boolean).map(Number)
    return { action: 'move', indices: nums.slice(0, -1), to: nums[nums.length - 1] }
  }
  return { action: verb, indices: rest.flatMap(s => s.split(',')).filter(Boolean).map(Number) }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'todo',
      description: 'Status-line todo list: add, edit, mv, done, fail, wip, undo, rm, clear',
      argumentHint: '[add|edit|mv|done|fail|wip|undo|rm|clear] …',
    })
    await $.tool.register({
      name: 'todo',
      description:
        "Edit the user's personal todo list shown in their status line (one per session). " +
        'Use only when the user asks about their todo list / status-line todos, not for your own task tracking. ' +
        'Actions: list; add (items: strings; optional to: 1-based position to insert at, default the end); ' +
        'edit (indices + items paired one-to-one: new text, keeping state and position); ' +
        'move (indices + to: the items, in list order, land at position to, keeping states); ' +
        'done (green 󰄵), fail (red 󰅘: failed/blocked), ' +
        'wip (yellow 󰛲: in progress/partial), undo (back to open 󰄱), remove — all take indices: 1-based numbers as shown by list; ' +
        'clear (removes done items, or everything with all: true). Returns the list after the change. ' +
        'To update an item use edit, not remove + add (that moves it to the end and resets its state).',
      inputSchema: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['list', 'add', 'edit', 'move', 'done', 'fail', 'wip', 'undo', 'remove', 'clear'] },
          items: { type: 'array', items: { type: 'string' } },
          indices: { type: 'array', items: { type: 'integer' } },
          to: { type: 'integer' },
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
