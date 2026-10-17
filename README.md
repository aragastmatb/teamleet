# TeamLeet — a team lead simulator

Godot 4.6, Russian and English (switch in-game). No assets, all UI built in code. Run with F5.

Two working weeks with a team of four. Tasks arrive daily; you assign them with a tone, pair people up, and hold one one-on-one a day. Ending the day simulates the work: progress, quality, fatigue, mood and skill growth.

- Skills and motives are hidden and revealed by results, the pace of work, and one-on-ones. Skills vary a little each run.
- Overload leads to sick leave, resentment to resignation; Vika's ambition can cost you your job.
- Morning scenes grow out of what's happening: Alex and Vika argue over credit after working together, Dima confesses a mistake, Gena forgets a task at the bottom of his list, Irina asks about a deadline that's slipping, Taras wants to borrow someone. Choices leave consequences that come back later.
- Friday reviews: credit yourself or whoever did the work, blame them or take responsibility.
- Endings follow your style: master of delegation, a leader people follow, workaholic, replaced by Vika, the team fell apart, removed.

## Files (`teamlead/`)
- `content.gd` — people, tones, tasks, schedule; all hidden numbers.
- `scenes.gd` — morning scenes: when they trigger, choices, consequences.
- `rules.gd` — the engine, no UI; can be driven headless.
- `locale.gd` — all RU/EN text.
- `main.gd` — the UI.
