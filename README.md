# Trajectory

A private, local-first desktop "life OS": vision goals, projects, habits, a weekly planner, focus sessions, a future-self mirror, an honest weekly review, commitments, and an AI coach. Built in Flutter from the *Trajectory Prototype* Claude Design.

## Run

```bash
flutter pub get
flutter run -d linux        # or -d macos / -d windows
flutter test
```

The app starts empty: no demo data. Every number (momentum, votes, charts, projections, badges) is computed from what you actually log. On first launch you go through onboarding: create a PIN, save a recovery phrase, then set your identity, goals, habits, rhythm, AI provider and partner. After that the app opens on the lock screen.

**Shortcuts:** `Ctrl K` command palette · `Ctrl ⇧ Space` quick capture · `Esc` closes overlays · digits/backspace on the lock screen.

**Page tours:** each page shows a guided tour on first visit (spotlight + Back/Next; `→`/`Enter`, `←`, `Esc` work too). Replay with the **?** button in the sidebar, "Show tour for this page" in the palette, or Settings → Replay all page tours. Steps live in `lib/shell/tour_content.dart`; mark a widget with `TourTarget(id: …)` to make it a stop.

**Look:** Mulish type, glass surfaces (backdrop blur, 1px inner border, top highlight, tinted shadow) over soft theme-colored ambient light, an icon rail plus collapsible panel sidebar, Phosphor icons. Settings → Appearance → Glass effects switches to solid surfaces (also automatic with the OS high-contrast setting).

**Window:** frameless. Hover the top-right corner to reveal minimize / maximize / close; drag the window by its top edge.

**Debug-only helpers:** `TRAJECTORY_SCREEN=today` and `TRAJECTORY_THEME=calm|editorial|telemetry` jump straight to a screen or theme. Release builds ignore them.

## Layout

```
lib/
  main.dart              app root, keyboard shortcuts, screen switcher, overlays
  theme/tokens.dart      the three design directions (Calm, Editorial, Telemetry) as tokens
  state/
    app_state.dart       single ChangeNotifier holding all state and actions
    models.dart          JSON-serialisable data models
    storage.dart         JSON file in the platform app-support folder
  services/
    security.dart        PBKDF2 PIN / recovery-phrase hashing, phrase generator
    capture_parser.dart  "fix JWT bug tomorrow 6pm" → title/time/day/goal
    coach.dart           Claude (Messages API) and Ollama clients
  shell/                 sidebar, tray widget, command palette, quick capture, friction gate, toast
  widgets/common.dart    design-system primitives (Panel, Btn, Ring, Bars, Segmented, …)
  screens/               one file per screen (16)
assets/google_fonts/     bundled Mulish, Geist, Geist Mono, Instrument Serif, Archivo Black, JetBrains Mono (OFL)
assets/fonts/            Phosphor Regular icon font (MIT); glyphs mapped in lib/theme/icons.dart
```

## What's real vs. simulated

Real and saved to disk:
- **Lock screen:** salted PBKDF2-HMAC-SHA256 hashes of the PIN and recovery phrase. 5 misses → 30s lockout, doubling. Auto-lock after idle time. Reset via recovery phrase.
- Tasks, quick capture parsing, habit check-ins, urge logging with triggers, goals (add/edit/delete, drift detection), projects (kanban drag-and-drop, milestones, tasks, notes), planner (schedule, unschedule, mark done/missed, auto-reschedule, lock week), focus timer, contracts, proof wall, settings, JSON/Markdown export.
- **AI (Claude `claude-opus-5-5`, or local Ollama `llama3.2`):**
  - *AI day plan* on Today — schedules open tasks around your peak window (structured JSON output); Accept writes times to tasks and blocks to the Planner.
  - *Project breakdown* — description → milestones with tasks and hour estimates.
  - *Weekly review* — "Write it with AI" turns your real planner/task/habit data into the report, wins, slips, adjustments and next-week draft.
  - *Coach* — multi-turn chat; only the context boxes you tick are sent.
  - Every feature falls back to an offline version when no provider is set or a call fails, and errors are shown in plain words (401 → "Claude rejected the API key…").
  - Keys must start with `sk-ant-`; onboarding and Settings refuse anything else (e.g. a pasted recovery phrase).

Simulated, or needs native integration later:
- **Data at rest is not encrypted.** The PIN gates access to the app, but `trajectory.json` is plain JSON. The AI key sits in a separate owner-only (`chmod 600`) file, not the OS keychain. Next steps: `flutter_secure_storage` for the key, and encrypting the state file with a key derived from the PIN.
- **Friction gate** is an in-app overlay. Real site blocking would need a browser extension or a hosts/DNS helper.
- **Tray widget** is an in-app popover. A real menu-bar icon would need a plugin such as `tray_manager`.
- **Global quick capture**: `Ctrl ⇧ Space` only works while the window has focus. System-wide would need `hotkey_manager`.
- Accountability partner notifications and calendar sync aren't implemented (the partner settings are stored, nothing is sent).
