import type { Engine, Register } from 'claude-code'

// Claude Code only labels INSERT and VISUAL in the hint line; NORMAL has no label,
// so a hint without one is read as NORMAL.
const LABEL = /-- (INSERT|VISUAL(?: LINE| BLOCK)?) --\s*/

// The permission-mode pill's "(shift+tab to cycle)" reminder, and the separator after it.
const CYCLE_HINT = /\(shift\+tab to cycle\)(\s*·\s*)?/

const COLORS: Record<string, string> = { NORMAL: 'blue', INSERT: 'green' }
const colorFor = (mode: string) => COLORS[mode] ?? (mode.startsWith('VISUAL') ? 'magenta' : 'white')

// DECSCUSR: steady block for NORMAL/VISUAL, steady bar for INSERT.
const cursorFor = (mode: string) => (mode === 'INSERT' ? '\x1b[6 q' : '\x1b[2 q')

// Walk up from the helper shell to the first ancestor with a real tty: the terminal
// Claude Code is drawing on. Same approach as ~/.claude/statusline.sh.
const FIND_TTY = `pid=$PPID
while [ "\${pid:-1}" -gt 1 ]; do
  t=$(ps -o tty= -p "$pid" | tr -d ' ')
  [ -n "$t" ] && [ "$t" != "?" ] && { echo "/dev/$t"; exit 0; }
  pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done
exit 1`

let tty: Promise<string | null> | null = null
let lastMode = ''

async function setCursor($: Engine, mode: string) {
  if (mode === lastMode) return
  lastMode = mode
  tty ??= $.process
    .run(['sh', '-c', FIND_TTY])
    .then(r => (r.exitCode === 0 ? r.stdout.trim() : null))
    .catch(() => null)
  const path = await tty
  if (path) await $.fs.write(path, cursorFor(mode)).catch(() => {})
}

// Matches the engine's own formatting: 3s, 1m 4s, 1h 2m 3s.
function formatDuration(ms: number) {
  const total = Math.max(0, Math.round(ms / 1000))
  const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), sec = total % 60
  return [h && `${h}h`, (h || m) && `${m}m`, `${sec}s`].filter(Boolean).join(' ')
}

export const register: Register = on => {
  // The bullet opening each reply, in Anthropic orange. ● (U+25CF), not ⏺: JetBrainsMono
  // lacks U+23FA, so it falls back to Noto Color Emoji, which ignores the text color. Only the first block of a reply
  // carries it; the rest (and other surfaces) draw as the engine does.
  on('ui.render', { component: 'AssistantMessage' }, ($, e, next) => {
    if (e.surface !== 'terminal' || !e.props.isFirstOfReply) return next(e)
    const { Box, Text, Markdown } = $.ui.resolve(e)
    return (
      <Box flexDirection="row">
        <Box width={2} flexShrink={0}>
          <Text color="#d97757">●</Text>
        </Box>
        <Box flexDirection="column" flexGrow={1}>
          <Markdown text={e.props.text} />
        </Box>
      </Box>
    )
  })

  // The end-of-turn line ("✻ Baked for 3s"): Anthropic orange flower (#D97757, as the
  // statusline model name) and bright white text (color 15, as the omp prompt).
  on('ui.render', { component: 'TurnDuration' }, ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box marginTop={1}>
        <Text color="#d97757">✻ </Text>
        <Text color="whiteBright">{e.props.word} for {formatDuration(e.props.durationMs)}</Text>
      </Box>
    )
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const m = e.props.hint.match(LABEL)
    const mode = m ? m[1] : 'NORMAL'
    const rest = (m ? e.props.hint.replace(m[0], '') : e.props.hint).replace(CYCLE_HINT, '').trim()
    await setCursor($, mode)

    const color = colorFor(mode)
    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box>
        <Text color={color}>{'\ue0ba'}</Text>
        <Text color="black" backgroundColor={color} bold>{` ${mode} `}</Text>
        <Text color={color}>{'\ue0b8'}</Text>
        {rest ? <Text dimColor> {rest}</Text> : null}
      </Box>
    )
  })
}
