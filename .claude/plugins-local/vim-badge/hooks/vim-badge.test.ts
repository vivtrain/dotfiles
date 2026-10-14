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

test('draws the end-of-turn line: orange flower, omp-teal text', async $ => {
  const ui = await $.ui.mount({ plugin: 'vim-badge', component: 'TurnDuration', surface: 'terminal', props: { word: 'Baked', durationMs: 64_000 } })
  expect(await ui.drawn()).toMatchObject({ type: 'Box', props: { marginTop: 1 } })
  expect(await ui.find({ type: 'Text', text: '✻' })).toMatchObject({ props: { color: '#d97757' } })
  expect(await ui.find({ type: 'Text', text: 'Baked for 1m 4s' })).toMatchObject({ props: { color: '#73a7a7' } })
})

test('draws an orange bullet on the first block of a reply', async $ => {
  const first = await $.ui.mount({ plugin: 'vim-badge', component: 'AssistantMessage', surface: 'terminal', props: { text: 'Hello **there**', isFirstOfReply: true } })
  expect(await first.drawn()).toMatchObject({ type: 'Box', props: { marginTop: 1 } })
  expect(await first.find({ type: 'Text', text: '●' })).toMatchObject({ props: { color: '#d97757' } })
  expect(await first.find({ type: 'Markdown' })).toMatchObject({ props: { text: 'Hello **there**' } })
})

test('stamps the end-of-turn line with the time its turn ended, omp-style', async ($, on) => {
  on('process.run', (_$, e) => ({ value: { exitCode: 0, stdout: e.argv[0] === 'date' ? '10:29:30 am\n' : '', stderr: '' } }))
  on('turn.complete', () => ({ text: '' }))
  await $.turn.complete({ answer: '', durationMs: 12_000, isAborted: false, turnId: 't1', reason: 'end_turn' } as never)
  const ui = await $.ui.mount({ plugin: 'vim-badge', component: 'TurnDuration', surface: 'terminal', props: { word: 'Cooked', durationMs: 12_000 } })
  expect(await ui.find({ type: 'Text', text: 'Cooked for 12s' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '\uf017 10:29:30 am' })).toMatchObject({ props: { color: '#00ffff' } })
})

test('draws no timestamp for a line with no recorded turn', async $ => {
  const ui = await $.ui.mount({ plugin: 'vim-badge', component: 'TurnDuration', surface: 'terminal', props: { word: 'Baked', durationMs: 99_000 } })
  expect(await ui.find({ type: 'Text', text: ' at ' })).toBeUndefined()
})
