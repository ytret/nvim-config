local M = {}

local tabs = require("ytret.tabs")

-- State of the currently open prompt: { buf, win, cfg }. Nil when closed.
local state

local FOOTER_HINT = " <CR> cd   <S-CR>/<C-e> tcd   <Esc> cancel "

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

local function close_prompt()
    if not state then
        return
    end
    local win = state.win
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
    local cfg = vim.tbl_extend("force", state.cfg, { footer = msg, footer_pos = "left" })
    vim.api.nvim_win_set_config(state.win, cfg)
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

    local width = math.min(math.max(#prefill + 12, 24), math.max(vim.o.columns - 4, 10))
    local cfg = {
        relative = "editor",
        anchor = "SW",
        width = width,
        height = 1,
        row = math.max(vim.o.lines - 4, 1),
        col = 2,
        style = "minimal",
        border = "rounded",
        title = " cd ",
        footer = FOOTER_HINT,
        footer_pos = "left",
    }
    local win = vim.api.nvim_open_win(buf, true, cfg)
    vim.wo[win].wrap = false

    state = { buf = buf, win = win, cfg = cfg }
    set_maps(buf)
    vim.api.nvim_win_set_cursor(win, { 1, #prefill })
    vim.cmd("startinsert!")
end

---The open prompt's state, or nil. Exposed for tests.
function M._state() return state end

vim.keymap.set("n", "<leader>ca", function() M._open("/") end, { desc = "cd: prompt from /" })
vim.keymap.set("n", "<leader>cs", function() M._open("~/") end, { desc = "cd: prompt from ~/" })
vim.keymap.set("n", "<leader>cd", function() M._open(tabs.get_global_cwd()) end, {
    desc = "cd: prompt from project dir",
})

return M
