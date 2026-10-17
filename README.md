# TeamLeet — a team lead simulator

Godot 4.6, Russian and English (switch in-game). No assets, all UI built in code. Run with F5.

Two working weeks with a team of four. Tasks arrive daily; you assign them with a click, pair people up, and hold one one-on-one a day. People with a reason to refuse push back, and you pick how to talk them round: tell it straight, flatter, cite the boss, promise a breather, or insist. Flattery and citing the boss only work when true; a lie about the boss may come out that evening. Ending the day simulates the work: progress, quality, fatigue, mood and skill growth.

- Skills and motives are hidden and revealed by results, the pace of work, and one-on-ones. Skills vary a little each run.
- Overload leads to sick leave, resentment to resignation; Vika's ambition can cost you your job.
- Morning scenes grow out of what's happening: Alex and Vika argue over credit after working together, Dima confesses a mistake, Gena forgets a task at the bottom of his list, Irina asks about a deadline that's slipping, Taras wants to borrow someone. Choices leave consequences that come back later.
- Fridays: a report on who worked how many hours, then Irina asks about the week's most visible success and worst failure. Answers are checked against the truth: claiming personal control only holds if you took part, blaming the owner only if they could do it and weren't overworked, "we were swamped" only if the report shows overtime.
- Endings follow your style: master of delegation, a leader people follow, workaholic, replaced by Vika, the team fell apart, removed.

## Files (`teamlead/`)
- `content.gd` — people, tones, tasks, schedule; all hidden numbers.
- `scenes.gd` — morning scenes: when they trigger, choices, consequences.
- `rules.gd` — the engine, no UI; can be driven headless.
- `locale.gd` — all RU/EN text.
- `main.gd` — the UI.
