# AGENTS.md — ytret's Neovim config

Guidance for coding agents working in this repo. Read this first to avoid
re-deriving context that is cheap to state but expensive to discover.

## What this is

Personal Neovim config (Lua), managed with **lazy.nvim**, tests run with
**plenary.nvim**. Entry point is `init.lua` → `require("ytret")`.

## Layout (where things live)

| Path | Purpose |
|------|---------|
| `init.lua` | Bootstraps `require("ytret")` only. |
| `lua/ytret/init.lua` | Loads `remap`, `lazy`, `set`, `tabs` (and optional local overrides). |
| `lua/ytret/lazy.lua` | lazy.nvim plugin specs. |
| `lua/ytret/set.lua` | `vim.opt` options. Leader = `<Space>` (set in `remap.lua`). |
| `lua/ytret/remap.lua` | General keymaps. |
| `lua/ytret/tabs.lua` | **Custom tab handling**: keymaps, tab prompt, custom `tabline()`, statusline, and the tab-local cwd logic (see below). |
| `lua/ytret/tabprompt.lua` | Interactive tab-number picker used by `tabs.lua`. |
| `lua/ytret/path.lua` | Path helpers (`bufadd_prefer_rel`, etc.). |
| `lua/ytret/fzf-setup.lua` | fzf-lua config + custom actions. |
| `after/plugin/*.lua` | Plugin setup that runs after plugins load (lsp, fzf, treesitter, nvim-tree, conform, etc.). |
| `plugin/*.lua` | `autotheme.lua` (theme switching), `lastpos.lua` (restore cursor pos). |
| `plugins/yt-window-picker/` | Local plugin (window picker), on `package.path` via lazy + tests. |
| `ftplugin/` | `go.lua`, `info.vim`. |

## Testing

- Run **all** tests: `./run_tests.sh` (headless Neovim + plenary).
- Run **one** dir/file: `./run_tests.sh tests` is the default; the script takes
  an optional directory arg. To run a single spec, point plenary at it, e.g.
  `nvim --headless -c "lua require('plenary.test_harness').test_directory('tests', {minimal_init='tests/init.lua'})" -c q`.
- `tests/init.lua` prepends `lua/` and `plugins/yt-window-picker/lua/` to
  `package.path`, so specs `require("ytret.<mod>")` directly.
- Specs are busted-style (`describe`/`it`/`before_each`/`after_each`) via plenary.
- **`after_each`/`before_each` in tab tests must restore cwd and tab count** —
  several specs `cd`/`tcd`/`tabnew` and would otherwise leak state into the next test.

### Headless Neovim hangs — always background + timeout

`nvim --headless -c ... -c q` can **hang** (the `-c q` does not always exit).
Never run it bare in the foreground. Use a background + watchdog pattern and a
tool `timeout`:

```bash
cd /tmp && ( nvim --headless -c "lua ..." -c "q" 2>&1 & NPID=$!; \
  ( sleep 20; kill -9 $NPID 2>/dev/null ) & WPID=$!; \
  wait $NPID 2>/dev/null; kill $WPID 2>/dev/null )
```

`timeout(1)` is **not** installed on this macOS machine — use the `sleep`/`kill`
watchdog above, and set the tool's own `timeout` parameter.

## Tab-local cwd — important, non-obvious

This config deliberately changes how `:tcd` interacts with new tabs. When
editing `tabs.lua`, keep these invariants:

- **Global cwd is tracked manually** in the `global_cwd` upvalue, updated via a
  `DirChanged` (`pattern = "global"`) autocmd. **Do not use `vim.fn.getcwd(-1)`
  to read the global cwd** — it is unreliable once any tab has used `:tcd` (it
  can return the tab-local value). Tests assert against
  `require("ytret.tabs").get_global_cwd()` instead.
- **`TabNew` autocmd** resets a brand-new tab's cwd to `global_cwd`, because
  default Neovim copies the *parent* tab's `:tcd` into new tabs. Net effect:
  new tabs always start at the global `:cd` directory.
- When a tab test needs `:tcd` to be genuinely tab-local, there must be **2+
  tabs** (with a single tab, `:tcd` elevates to global scope).

## Statusline / tabline gotcha (cost a real bug)

The **tabline is a statusline-format string** (`vim.o.tabline = "%!..."`), so
`%` is the escape character. A **literal `%` must be written `%%`** in anything
the tabline prints, otherwise Neovim parses `%X` as a statusline item: it
renders nothing but still consumes width (the "shrunk by 1 char" symptom).

Text returned from an **evaluated** `%{...}`/`v:lua` item (e.g. the statusline's
`twd_statusline()`) is **not** re-scanned, so a `%` there is safe unescaped.

Current behavior:
- **Statusline** (right side): always shows the current tab's cwd, truncated to
  30 chars (head-elided `...`), suffixed with `%` when it differs from global.
- **Tabline**: each tab whose cwd differs from global gets a `%` appended to its
  label.

## Conventions

- **Commits**: short subject, `<file/area>: <what changed>`, e.g.
  `tabs.lua: fix ...`, `tests: tabs_spec.lua: add ...`. Implementation and its
  tests are usually committed as **separate** commits (impl first, then tests),
  except small bugfixes which go together. **Do not push** unless explicitly asked.
- **Formatting**: stylua (`stylua.toml`): spaces, width 100,
  `collapse_simple_statement = "FunctionOnly"`, sorted requires. Match the
  existing 4-space Lua indent and doc-comment (`---@param`) style.
- **Local overrides**: `lua/ytret/local-pre.lua` / `local-post.lua` are
  git-ignored machine-specific hooks loaded via `pcall` — don't create
  dependencies on them.
- Modules under `lua/ytret/` return a table `M` and expose internals prefixed
  `_` only for testing (e.g. `M._scrolled_range`).

## macOS notes

- `/tmp`, `/var` are symlinks → `vim.fs.normalize` / `fs_realpath` resolve them
  to `/private/tmp`, `/private/var`. Tests use `/usr` (not a symlink) when a
  stable path is needed; don't assert on `/tmp` literally.
- No `timeout(1)` coreutil (see "Headless Neovim hangs" above).
