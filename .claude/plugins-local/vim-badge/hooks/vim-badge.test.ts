import { expect, test } from 'claude-code/testing'

const HINT = { plugin: 'vim-badge', component: 'PromptHint' } as const
const props = (hint: string) => ({ isDraft: false, isWorking: false, hint })

test('badges the mode, drops the cycle hint, and sets the cursor once per change', async ($, on) => {
  const writes: { path: string; text: string }[] = []
  on('process.run', () => ({ value: { exitCode: 0, stdout: '/dev/pts/9\n', stderr: '' } }))
  on('fs.write', (_$, e) => { writes.push({ ...e }); return { value: undefined } })

  for (const surface of ['terminal', 'desktop'] as const) {
    writes.length = 0
    const ui = await $.ui.mount({ ...HINT, surface, props: props('-- INSERT -- (shift+tab to cycle) · ← for agents') })
    expect((await ui.find({ text: 'INSERT' }))).toBeDefined()
    expect((await ui.find({ text: '← for agents' }))).toBeDefined()
    expect(await ui.find({ text: '(shift+tab to cycle)' })).toBeUndefined()

    await ui.redraw(props('(shift+tab to cycle) · ← for agents'))
    expect(await ui.find({ text: 'NORMAL' })).toBeDefined()

    await ui.redraw(props('(shift+tab to cycle) · ← for agents'))
    await ui.unmount()

    // Module state carries across surfaces, so only the terminal pass starts from scratch.
    if (surface === 'terminal') {
      expect(writes).toEqual([
        { path: '/dev/pts/9', text: '\x1b[6 q' },
        { path: '/dev/pts/9', text: '\x1b[2 q' },
      ])
    }
  }
})

test('draws the end-of-turn line: orange flower, white text', async $ => {
  const ui = await $.ui.mount({ plugin: 'vim-badge', component: 'TurnDuration', surface: 'terminal', props: { word: 'Baked', durationMs: 64_000 } })
  expect(await ui.drawn()).toMatchObject({ type: 'Box', props: { marginTop: 1 } })
  expect(await ui.find({ type: 'Text', text: '✻' })).toMatchObject({ props: { color: '#d97757' } })
  expect(await ui.find({ type: 'Text', text: 'Baked for 1m 4s' })).toMatchObject({ props: { color: 'whiteBright' } })
})

test('draws an orange bullet on the first block of a reply', async $ => {
  const first = await $.ui.mount({ plugin: 'vim-badge', component: 'AssistantMessage', surface: 'terminal', props: { text: 'Hello **there**', isFirstOfReply: true } })
  expect(await first.drawn()).toMatchObject({ type: 'Box', props: { marginTop: 1 } })
  expect(await first.find({ type: 'Text', text: '●' })).toMatchObject({ props: { color: '#d97757' } })
  expect(await first.find({ type: 'Markdown' })).toMatchObject({ props: { text: 'Hello **there**' } })
})
