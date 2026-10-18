local M = {}

local tabs = require("ytret.tabs")

-- State of the currently open prompt: { buf, win, cfg }. Nil when closed.
local state

-- Keep the hint footer fully visible in the smallest window.
local FOOTER_HINT = " <CR> cd   <S-CR>/<C-e> tcd   <Esc> cancel "
local MIN_WIDTH = #FOOTER_HINT + 2
-- Preferred number of list rows in the directory picker.
local PICKER_ROWS = 16

---Expand a leading "~" using $HOME.
---@param path string
---@return string
local function expand_home(path)
    if path == "~" then
        return vim.env.HOME or path
    end
    if path:sub(1, 2) == "~/" then
        return (vim.env.HOME or "~") .. path:sub(2)
    end
    return path
end

---Resolve user input to an existing directory.
---@param input string
---@return string|nil dir
---@return string|nil err
function M._resolve(input)
    local raw = vim.trim(input or "")
    if raw == "" then
        return nil, "Empty path"
    end
    local dir = vim.fs.normalize(vim.fn.fnamemodify(expand_home(raw), ":p"))
    if vim.fn.isdirectory(dir) == 1 then
        return dir
    end
    if vim.fn.filereadable(dir) == 1 then
        return nil, "Not a directory: " .. dir
    end
    return nil, "No such directory: " .. dir
end

---Delete the path component before `col` (0-based byte offset).
---@param line string
---@param col integer
---@return string line
---@return integer col
function M._kill_component(line, col)
    local left = line:sub(1, col)
    local right = line:sub(col + 1)
    local core = (left:gsub("/+$", ""))
    if core == "" then
        return line, col
    end
    local slash = core:match("^.*()/")
    local new_left
    if not slash then
        new_left = ""
    elseif right:sub(1, 1) == "/" then
        new_left = core:sub(1, slash - 1)
    else
        new_left = core:sub(1, slash)
    end
    return new_left .. right, #new_left
end

---Start offset of the path component before `col`.
---@param line string
---@param col integer
---@return integer
function M._prev_boundary(line, col)
    local base = (line:sub(1, col):gsub("/+$", ""))
    return base:match("^.*()/") or 0
end

---Start offset of the path component after `col`.
---@param line string
---@param col integer
---@return integer
function M._next_boundary(line, col) return line:find("/", col + 1, true) or #line end

---Split the prompt line at the cursor into base dir and component.
---@param line string
---@param col integer 0-based cursor offset
---@return string base dir as typed ("", "~/", "/a/b/")
---@return string partial component under the cursor
---@return integer start 0-based offset where the component starts
---@return integer stop 0-based offset (exclusive) where the component ends
function M._split_component(line, col)
    local left = line:sub(1, col)
    local start = left:match("^.*()/") or 0
    local after = line:sub(col + 1):find("/", 1, true)
    local stop = after and col + after - 1 or #line
    return line:sub(1, start), line:sub(start + 1, stop), start, stop
end

---Resolve a base dir as typed ("" means the current directory).
---@param base string
---@return string|nil dir
---@return string|nil err
function M._resolve_base(base)
    local raw = base == "" and "." or base
    local dir = vim.fs.normalize(vim.fn.fnamemodify(expand_home(raw), ":p"))
    if vim.fn.isdirectory(dir) == 1 then
        return dir
    end
    if vim.fn.filereadable(dir) == 1 then
        return nil, "Not a directory: " .. dir
    end
    return nil, "No such directory: " .. dir
end

---Sorted names of the subdirectories of `dir`.
---@param dir string
---@return string[]|nil names
---@return string|nil err
function M._dir_candidates(dir)
    if vim.fn.isdirectory(dir) == 0 then
        return nil, "No such directory: " .. dir
    end
    local ok, entries = pcall(vim.fn.readdir, dir)
    if not ok or type(entries) ~= "table" then
        return nil, "Cannot read directory: " .. dir
    end
    local names = {}
    for _, name in ipairs(entries) do
        if vim.fn.isdirectory(dir .. "/" .. name) == 1 then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

---Change the working directory.
---@param dir string must be an existing directory
---@param scope string "global" (:cd) or "tabpage" (:tcd)
---@return boolean ok
function M._chdir(dir, scope)
    if vim.fn.isdirectory(dir) == 0 then
        return false
    end
    local escaped = vim.fn.fnameescape(dir)
    if scope == "tabpage" then
        vim.cmd("tcd " .. escaped)
        return true
    end
    -- A global :cd does not move tabs that own a :tcd; bring this tab along so
    -- the change is never a no-op.
    local tab_was_local = vim.fs.normalize(vim.fn.getcwd()) ~= tabs.get_global_cwd()
    vim.cmd("cd " .. escaped)
    if tab_was_local then
        vim.cmd("tcd " .. escaped)
    end
    return true
end

---The prompt's content width: a fixed 60% of the screen, never narrower than the
---hint footer. Fixed so the bar does not resize (and shift) while typing.
---@return integer
function M._prompt_width()
    local max_width = math.max(vim.o.columns - 4, 10)
    local wanted = math.floor(vim.o.columns * 0.6)
    return math.min(math.max(wanted, MIN_WIDTH), max_width)
end

---Centered float config; recomputed on resize.
---@return table
local function prompt_config()
    local width = M._prompt_width()
    local height = 1
    return {
        relative = "editor",
        width = width,
        height = height,
        -- Center the whole box, border included.
        row = math.max(math.floor((vim.o.lines - height - 2) / 2), 0),
        col = math.max(math.floor((vim.o.columns - width - 2) / 2), 0),
        style = "minimal",
        border = "rounded",
        title = " cd ",
        footer = FOOTER_HINT,
        footer_pos = "left",
    }
end

local function close_prompt()
    if not state then
        return
    end
    local win = state.win
    for _, id in ipairs(state.autocmds or {}) do
        pcall(vim.api.nvim_del_autocmd, id)
    end
    state = nil
    if vim.api.nvim_win_is_valid(win) then
        vim.cmd("stopinsert")
        vim.api.nvim_win_close(win, true)
    end
end

local function buffer_line()
    local line = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1]
    return line or ""
end

local function set_line(text, col)
    vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { text })
    vim.api.nvim_win_set_cursor(state.win, { 1, math.min(col, #text) })
end

local function set_footer(msg)
    state.cfg.footer = msg
    vim.api.nvim_win_set_config(state.win, state.cfg)
end

---Re-apply the config (centering and width) after a terminal resize.
local function recenter()
    if not state or not vim.api.nvim_win_is_valid(state.win) then
        return
    end
    local footer = state.cfg.footer
    state.cfg = prompt_config()
    state.cfg.footer = footer
    vim.api.nvim_win_set_config(state.win, state.cfg)
end

local function accept(scope)
    if not state then
        return
    end
    local dir, err = M._resolve(buffer_line())
    if not dir then
        set_footer(" " .. err .. " ")
        return
    end
    close_prompt()
    M._chdir(dir, scope)
end

---Put `name` into the prompt in place of the component at [start, stop].
---@param line string prompt line the picker was opened from
---@param name string chosen directory name
---@param start integer
---@param stop integer
local function insert_component(line, name, start, stop)
    if not state then
        return
    end
    local base = line:sub(1, start)
    local rest = line:sub(stop + 1)
    if rest:sub(1, 1) == "/" then
        rest = rest:sub(2)
    end
    if not vim.api.nvim_win_is_valid(state.win) then
        return
    end
    pcall(vim.api.nvim_set_current_win, state.win)
    set_line(base .. name .. "/" .. rest, #base + #name + 1)
    recenter()
    if vim.api.nvim_get_current_win() == state.win then
        vim.cmd("startinsert!")
    end
end

---Keep the tail of `text` (the meaningful part of a path) within `max` bytes.
---@param text string
---@param max integer
---@return string
function M._head_elide(text, max)
    max = math.max(max, 1)
    if #text <= max then
        return text
    end
    local ellipsis = "\u{2026}"
    if max <= #ellipsis then
        return text:sub(-max)
    end
    return ellipsis .. text:sub(#text - (max - #ellipsis) + 1)
end

---Picker geometry: the prompt's exact width and left edge, docked right below it.
---fzf-lua counts the border in `width`/`height`, while `row`/`col` are the
---footprint's top-left, so a picker under the prompt gets
---`row = prompt.row + 2` (1 content row + 1 bottom border), `col = prompt.col - 1`.
---@return table
function M._picker_winopts()
    local cfg = state.cfg
    local avail = vim.o.lines - (cfg.row + 2) - vim.o.cmdheight
    -- Prefer PICKER_ROWS list rows (plus its border), shrinking to whatever
    -- fits below the prompt so the picker never runs off the screen.
    local total = avail >= 3 and math.min(PICKER_ROWS + 2, avail) or math.max(avail, 1)
    return {
        -- The user config turns fullscreen on for every picker; opt out here.
        fullscreen = false,
        width = cfg.width + 2,
        height = total,
        -- Normally right below the prompt; pulled up only if that would not fit.
        row = math.min(cfg.row + 2, math.max(vim.o.lines - vim.o.cmdheight - total, 0)),
        col = math.max(cfg.col - 1, 0),
    }
end

---Complete the path component under the cursor with a directory picker.
function M._pick_component()
    if not state then
        return
    end
    local line, col = buffer_line(), vim.api.nvim_win_get_cursor(state.win)[2]
    local base, partial, start, stop = M._split_component(line, col)
    local dir, err = M._resolve_base(base)
    if not dir then
        set_footer(" " .. err .. " ")
        return
    end
    local names, derr = M._dir_candidates(dir)
    if not names then
        set_footer(" " .. derr .. " ")
        return
    end
    if #names == 0 then
        set_footer(" No subdirectories: " .. dir .. " ")
        return
    end
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
        set_footer(" fzf-lua not available ")
        return
    end
    local winopts = M._picker_winopts()
    fzf.fzf_exec(names, {
        prompt = "cd> ",
        query = partial,
        header = " " .. M._head_elide(line, winopts.width - 4) .. " ",
        winopts = winopts,
        previewer = false,
        actions = {
            ["default"] = function(selected)
                local name = selected and selected[1]
                if not name or name == "" then
                    return
                end
                vim.schedule(function() insert_component(line, name, start, stop) end)
            end,
        },
    })
end

local function set_maps(buf)
    local function imap(lhs, fn) vim.keymap.set("i", lhs, fn, { buffer = buf, nowait = true }) end
    imap("<CR>", function() accept("global") end)
    imap("<S-CR>", function() accept("tabpage") end)
    imap("<C-e>", function() accept("tabpage") end)
    imap("<C-w>", function()
        local line, col = buffer_line(), vim.api.nvim_win_get_cursor(state.win)[2]
        set_line(M._kill_component(line, col))
    end)
    imap("<M-BS>", function()
        local line, col = buffer_line(), vim.api.nvim_win_get_cursor(state.win)[2]
        set_line(M._kill_component(line, col))
    end)
    imap("<M-b>", function()
        local line, col = buffer_line(), vim.api.nvim_win_get_cursor(state.win)[2]
        set_line(line, M._prev_boundary(line, col))
    end)
    imap("<M-f>", function()
        local line, col = buffer_line(), vim.api.nvim_win_get_cursor(state.win)[2]
        set_line(line, M._next_boundary(line, col))
    end)
    imap("<Tab>", M._pick_component)
    imap("<Esc>", close_prompt)
    imap("<C-c>", close_prompt)
    -- Fallbacks in case the prompt is not in insert mode.
    vim.keymap.set("n", "<CR>", function() accept("global") end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "<Esc>", close_prompt, { buffer = buf, nowait = true })
end

---Open the path prompt, prefilled with `prefill`.
---@param prefill string
function M._open(prefill)
    prefill = prefill or ""
    close_prompt()

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prefill })

    local cfg = prompt_config()
    local win = vim.api.nvim_open_win(buf, true, cfg)
    vim.wo[win].wrap = false

    state = { buf = buf, win = win, cfg = cfg }
    state.autocmds = {
        vim.api.nvim_create_autocmd("VimResized", { callback = recenter }),
        -- Leaving the prompt (the directory picker, another window) drops insert
        -- mode; put it back when the prompt is focused again.
        vim.api.nvim_create_autocmd("WinEnter", {
            buffer = buf,
            callback = function() M._reenter_insert() end,
        }),
    }
    set_maps(buf)
    vim.api.nvim_win_set_cursor(win, { 1, #prefill })
    vim.cmd("startinsert!")
end

---Enter insert mode once a pending mode transition has settled.
---fzf-lua restores focus before its own stopinsert applies, so requesting insert
---immediately would be clobbered; wait for the mode to actually be normal.
---@param tries integer|nil
local function enter_insert_when_settled(tries)
    tries = tries or 0
    if not state or not vim.api.nvim_win_is_valid(state.win) then
        return
    end
    if vim.api.nvim_get_current_win() ~= state.win then
        return
    end
    if vim.fn.mode() == "n" then
        -- Plain startinsert keeps the cursor where it was.
        vim.cmd("startinsert")
        return
    end
    if tries >= 20 then
        return
    end
    vim.defer_fn(function() enter_insert_when_settled(tries + 1) end, 10)
end

---Re-enter insert mode if the prompt window is focused. Exposed for tests.
---@return boolean entered
function M._reenter_insert()
    if not state or not vim.api.nvim_win_is_valid(state.win) then
        return false
    end
    if vim.api.nvim_get_current_win() ~= state.win then
        return false
    end
    enter_insert_when_settled(0)
    return true
end

---The open prompt's state, or nil. Exposed for tests.
function M._state() return state end

vim.keymap.set("n", "<leader>ca", function() M._open("/") end, { desc = "cd: prompt from /" })
vim.keymap.set("n", "<leader>cs", function() M._open("~/") end, { desc = "cd: prompt from ~/" })
vim.keymap.set("n", "<leader>cd", function() M._open(tabs.get_global_cwd()) end, {
    desc = "cd: prompt from project dir",
})

return M
