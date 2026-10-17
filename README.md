# This Meeting Could Have Been an Email — team lead simulator

Godot 4.6, Russian and English (switch in-game). No assets, all UI built in code. Run with F5.

Two working weeks with a team of four. Tasks arrive daily; you assign them with a tone, pair people up, and hold one one-on-one a day. Ending the day simulates the work: progress, quality, fatigue, mood and skill growth.

- Skills and motives are hidden and revealed by results, the pace of work, and one-on-ones. Skills vary a little each run.
- Overload leads to sick leave, resentment to resignation; Vika's ambition can cost you your job.
- Friday reviews: credit yourself or whoever did the work, blame them or take responsibility.
- Endings follow your style: master of delegation, a leader people follow, workaholic, replaced by Vika, the team fell apart, removed.

## Files (`teamlead/`)
- `content.gd` — people, tones, tasks, schedule; all hidden numbers.
- `rules.gd` — the engine, no UI; can be driven headless.
- `locale.gd` — all RU/EN text.
- `main.gd` — the UI.
