// When each main-loop turn ended, keyed by its duration so the end-of-turn line can find it.
export type TurnEnd = { durationMs: number; at: string }

declare module 'claude-code' {
  interface PluginState {
    'vim-badge': { turnEnds: TurnEnd[] }
  }
}
