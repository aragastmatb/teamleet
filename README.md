# TeamLeet — a team lead simulator

Godot 4.6, Russian and English (switch in-game). No assets, all UI built in code. Run with F5.

A four-week probation as the new lead of a team of four. On day one Irina names three key projects; at the end comes an assessment that weighs results (mostly those projects) against an anonymous team survey Marina runs halfway and at the end. Tasks arrive daily; you assign them with a click, pair people up, and hold one one-on-one a day. People with a reason to refuse push back, and you pick how to talk them round: tell it straight, flatter, cite the boss, promise a breather, or insist. Flattery and citing the boss only work when true; a lie about the boss may come out that evening. Ending the day simulates the work: progress, quality, fatigue, mood and skill growth.

- Skills and motives are hidden and revealed by results, the pace of work, and one-on-ones. Skills vary a little each run.
- Overload leads to sick leave, resentment to resignation; Vika's ambition can cost you your job.
- Tasks hit complications while they're being worked on (an old bug, missing access, scope creep, broken data, a client changing their mind…); your call changes scope, deadline or quality, and some calls depend on the owner's real skill.
- Roles aren't assigned: they emerge from the tasks someone ends up doing.
- Morning scenes grow out of what's happening: Alex and Vika argue over credit after working together, Dima confesses a mistake, Gena forgets a task at the bottom of his list, Irina asks about a deadline that's slipping, Taras wants to borrow someone. Choices leave consequences that come back later.
- Fridays: a report of hours against the 40-hour week (yours included — a lead who does the work gets told off), then Irina asks about the week's most visible success and worst failure. Answers are checked against the truth: claiming personal control only holds if you took part, blaming the owner only if they could do it and weren't overworked, "we were swamped" only if the report shows overtime.
- Weight with Irina (shown in the top bar as how much she listens to you) grows when you're visible — key projects delivered, credit taken, honest early warnings — and drops with slips and lies. It's spent to protect the team: refusing tasks she drops on you, getting a contractor. Every change is announced with its cause; Taras and Vika show by example how weight is made. Enough of it at the end means a promotion.
- Assessment outcomes: results and team (a leader people follow), results without the team (master of delegation), the team without results (the team's favourite, probation failed), neither (failed); plus workaholic, replaced by Vika, the team fell apart.

## Files (`teamlead/`)
- `content.gd` — people, tones, tasks, schedule; all hidden numbers.
- `scenes.gd` — morning scenes: when they trigger, choices, consequences.
- `rules.gd` — the engine, no UI; can be driven headless.
- `locale.gd` — all RU/EN text.
- `main.gd` — the UI.
