# Testing & Refactoring Plan

## Overview

This document outlines what to test next in this Neovim config and in what order.
The driving principle: **refactoring targets need tests first**.

## 1. `lua/ytret/path.lua` — `bufadd_prefer_rel`

**Why first:** Most self-contained complex function. No plugin dependencies, only `vim.*` API calls. Tests would drive out cleaner decomposition of the buffer-deletion logic from the fallback chain.

**Complexity:** 7+ branches, side effects (deletes buffers), calls three helper functions (`canonical_path`, `find_buffer_by_path`, `is_buffer_visible`).

**Test plan:**
- Existing buffer found, name matches → returns existing
- Existing buffer found, name mismatch, deletable → deletes and re-adds
- Existing buffer found, name mismatch, not deletable → returns existing
- No existing buffer, `bufadd` with relative path succeeds → returns new buf
- `bufadd` with relative path fails, absolute path succeeds → returns new buf
- Both `bufadd` attempts fail → returns 0

**Refactoring target:** Extract buffer-deletion conditions into a predicate function `can_buffer_be_reused(bufnr)`. The fallback chain (relative → absolute → 0) is clean.

---

## 2. `plugins/yt-window-picker/lua/yt-window-picker/init.lua` — `index_to_label`

**Why second:** Rare pure function in this config. Trivial to test — input/output only. Good confidence-builder.

**Test plan:**
- 1 → "A", 2 → "B", …, 26 → "Z", 27 → "AA", 28 → "AB", 52 → "AZ", 53 → "BA"

---

## 3. Extract shared `set_buf_listed`

**Where duplicated:**
- `fzf-setup.lua:118`
- `lsp.lua:40`

**Plan:** Test both callers' behavior, then unify into a shared module (probably `path.lua` since it already manages buffer state).

**Test plan (per caller):**
- Stops insert mode
- Sets current buffer
- Marks buffer as listed
- Handles nil/invalid bufnr gracefully

---

## 4. `lua/ytret/fzf-setup.lua` — `has_real_target`

**Why:** 6-branch decision chain with a clear data-flow (selected → entry → path → exists). The fallthrough logic (nil → empty → relative path → stat) is a good refactoring target.

**Complexity:** 6+ branches, uses `fzf_path.entry_to_file` and `uv.fs_stat`.

**Note:** Depends on `fzf-lua` being available.

**Test plan:**
- nil/empty selection → false
- Invalid entry (pcall fails) → false
- Entry with URI → true
- Entry with valid bufnr → true
- Entry with absolute path that exists → true
- Entry with relative path that resolves to existing file → true
- Path does not exist → false

---

## 5. `plugin/autotheme.lua` — `apply_theme_file`

**Why:** 8+ branches with hardcoded per-theme highlight tables. The theme-specific configs (rose-pine dark/light, tokyonight, catppuccin, modus) should be extracted into a data structure.

**Complexity:** Heavy Neovim side effects (`colorscheme`, `nvim_set_hl`). Harder to test in isolation.

**Test plan:**
- Light/dark branch
- Each theme name → correct highlight configs applied
- Non-modus themes → background cleared
- Trailing whitespace conditional
- Tabline color variants (dark vs light)

**Refactoring target:** Extract per-theme color tables into a plain data structure. The highlight-application loop would be the same for all themes.

---

## 6. `after/plugin/lsp.lua` — `other_or_new_win`, `def_in_target`

**Why:** `def_in_target` orchestrates LSP response + window targeting + buffer loading. `other_or_new_win` has multi-branch window selection logic.

**Complexity:** `def_in_target` has 5+ branches; `other_or_new_win` has 3. Depends on LSP being active, making it harder to test in isolation.

---

## 7. Extract shared `tab_prompt` utility

**Duplicated pattern:** `getchar` for ≤9 tabs, `input` for >9 tabs.

**Where duplicated:**
- `fzf-setup.lua:with_picked_tab` (lines 70-111)
- `tabs.lua:prompt_move_tab` (lines 39-71)

**Plan:** Test both callers, extract shared function with signature like `prompt_for_tab(opts)` that returns `{ tabnr = number }` or `{ new = true }` or `nil`.

---

## 8. `lua/ytret/tabs.lua` — scrolling tabline

**Why:** `M.tabline` implements a custom 4-phase scrolling algorithm. The test base from `tests/tabs_spec.lua` already covers label correctness.

**Additional tests needed:**
- Tabline fits within columns → all tabs rendered
- Tabline exceeds columns → scroll indicators shown
- Active tab at extreme left/right → scrolling handles it
- Single tab, many tabs
- Tab retraction when arrows don't fit

---

## How to run tests

```bash
./run_tests.sh
```

## Adding new test files

1. Create `tests/<name>_spec.lua`
2. Use the plenary `describe`/`it` API (busted-compatible)
3. Run with `./run_tests.sh`
