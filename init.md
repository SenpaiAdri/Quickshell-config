# quickshell animation-inspection notes

Read this before touching island/center/wifi animations or verifying them visually.

## Hot-reload + logs

- Quickshell hot-reloads on every edit; broken QML stalls/fails **silently**.
- Log is binary: `strings /run/user/1000/quickshell/by-id/*/log.qslog`.
- Recency check (log accumulates across reloads — stale errors sit above):
  `strings .../log.qslog | grep -nE "Configuration Loaded|ReferenceError|Binding loop|Failed"`
  Only entries **after the last `Configuration Loaded`** count.
- Every edit triggers a reload, so intermediate broken states log errors.
  Judge only after the final edit + `sleep 6`.
- Any reload **resets component state** (`expandedGroups`, etc.) — test
  expand/collapse state is lost on every edit.
- Lint: `/usr/lib/qt6/bin/qmllint <file>` (warnings ok, errors not).
- After an edit, confirm a NEW `Configuration Loaded` line (timestamp
  must be after your edit). The watcher sometimes swallows a reload —
  if none appears, edit again (any content change) or restart quickshell;
  never trust screenshots until the reload is confirmed.

## QML gotchas (`pragma ComponentBehavior: Bound` is on)

- Unqualified reads of anything not on the delegate root (or self) throw
  `ReferenceError` at runtime; qmllint only warns (`Unqualified access`).
  Id-qualify all cross-object refs (`cardWrap.*`, `cardRect.*`).
- Repeater delegates need `required property int index` + `modelData`.
- Followers must never feed back into the layout they read (no loops):
  peeks may read Column geometry but must not affect `cardsCol`.

## Screenshot-testing animations

- `timeout 8 grim <file>`; grim latency is ~100–300ms, fans run ~400–500ms:
  fire grim immediately after the trigger for mid-flight frames.
- Plain `notify-send` doesn't block (`--action` does — background it).
  Toasts expire in 6s; `-u critical` = sticky test toast.
- **Kitty clipboard-permission toasts spam on every image read.** They
  overlay top-right (steal clicks), enter history (shift layout down), and
  land seconds AFTER the read that spawned them. Defenses:
  - `notifs dnd` on during capture windows (suppresses overlays only;
    history still grows), off after.
  - Click the lower half of cards, below the toast zone (~y 140).
  - Never `read` a screenshot between measuring coords and clicking.
  - `notifs clear` before each round; re-measure Collapse coords every round.
- Clicks: `hyprctl dispatch movecursor X Y` (verify with `hyprctl cursorpos`),
  then python-evdev `UInput` `BTN_LEFT` down (100ms) / up. `/dev/uinput` is
  ACL-writable. **Declare capabilities explicitly** — bare `UInput()`
  silently drops the button press (no error, cursor moves, nothing logs):
  `UInput({EV_KEY: [BTN_LEFT], EV_REL: [REL_X, REL_Y]}, name='qsclick')`,
  settle ~1.2s after creating the device (fresh devices miss fast events),
  then press. **Sleep ~0.25s between button-up and `ui.close()`** —
  closing immediately can swallow the release (press logs, `onClicked`
  never fires). Verify via `notifs debug` (`row press` log line).
  Clicking any other window clears `HyprlandFocusGrab` and the
  center closes.
- Round hygiene (strict order — a round without `clear` is INVALID):
  sleep ~10 (drain pending read-toasts) → close center → `notifs clear`
  → send test notifs → open → NO reads until click+burst are done.
  Every image `read` spawns a kitty toast that lands in history AFTER
  the clear if you read between clear and click.
- Missed Collapse clicks land on the card body below it — a no-op when
  expanded (only `stackTop` toggles). If state doesn't change, re-measure.
- IPC: `toggle | clear | dnd | status | debug` work. **`show`/`hide` are
  reserved words** — they print usage instead of running. Track open state
  and use `toggle`. Temp test IPC in `shell.qml` is allowed but must be
  removed after (verify: `grep -c`, `Function not found`, `git diff`).
- End every round tidy: `notifs clear`, `notifs toggle` (close), DND off.

## Video verification with wl-screenrec (2026-10-07, verified fan fix)

- `wl-screenrec -g "1450,0 470x700" -f out.mp4 &` (top-right center region),
  stop with `kill -INT`. Check `rec.log`: vaapi may warn, still records ~59fps.
- **Every agent tool call spawns ~1 kitty notif 5-100s later** (not just image
  reads). Single-command rounds + in-command `purge`+retry loops (verify via
  state after each click) are robust to this. Drive rounds with a python
  script (persistent UInput, `inspect` state checks); see `/tmp/opencode/round_*.py`.
- Temp test IPC (`purge`/`inspect` on `notifs`) is allowed for rounds but MUST
  be removed afterwards (verify `Function not found` + new reload + clean diff).
- Frame analysis without `read`: PIL pixel profiles (no numpy on host).
  `-ss` BEFORE `-i` snaps to keyframes (duplicate frames!) — put `-ss` AFTER
  `-i` and decode consecutive `-frames:v N` for true mid-flight frames.
- Measured coords (1920x1200, scale 1): collapsed stack-top body ≈ (1640,275)
  (stack 2nd) / (1640,150) (stack 1st); expanded `Collapse` text = screen
  (1835,218) (region-x 362-409, region-y 205-232; group ✕ core at 422-427).
  A `row press flat=N` with no toggle = click landed on inert card body.
- Evidence: `/tmp/opencode/fan-expand.mp4` (follower above),
  `fan-collapse.mp4` (bottom-first tuck), `fan-expand-below.mp4` (follower
  below — the exact pre-fix spill scenario; mid-fan shows follower displaced
  in sync, zero overlap). Verdict: fan works correctly both directions.

## Current fan implementation (`components/NotifCenter.qml`)

- All cards always instantiated; collapsed = height 0 + opacity 0 (not
  destroyed), so expand AND collapse animate. Gaps live inside wrapper
  heights; `Column.spacing` is 0.
- Peeks are pure followers of each wrapper's `expandRatio`
  (y / width / opacity / height interpolate tucked → card slot).
- `groupRoot.height` has NO Behavior: it tracks `cardsCol` synchronously
  (wrappers animate it). A Behavior here chases the moving target, lags
  followers, and lets expanding cards paint past the lagging delegate
  bounds over the card below. `ListView.displaced` is 150ms (ride the fan,
  still glide on insert/remove).
- Known wart: the count pill toggles instantly (pops for one frame at fan
  start, both directions). Layout + fade polish is a follow-up, not done.
