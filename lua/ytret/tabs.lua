local M = {}

local tabprompt = require("ytret.tabprompt")

-- Track the global cwd ourselves because getcwd(-1) is unreliable when
-- :tcd has been used in any tab (it can return the tab-local value).
local global_cwd = vim.fs.normalize(vim.fn.getcwd())

local cwd_groups = {}
local cwd_groups_by_index = {}
local next_cwd_group = 1

local cwd_group_symbols = {
    { greek = "α", key = "A" },
    { greek = "β", key = "B" },
    { greek = "γ", key = "G" },
    { greek = "δ", key = "D" },
    { greek = "ε", key = "E" },
    { greek = "ζ", key = "Z" },
    { greek = "η", key = "H" },
    { greek = "θ", key = "T" },
    { greek = "ι", key = "I" },
    { greek = "κ", key = "K" },
}

local function register_cwd_group(cwd)
    cwd = vim.fs.normalize(cwd)
    local existing = cwd_groups[cwd]
    if existing then
        return existing
    end

    local index = next_cwd_group
    local symbol = cwd_group_symbols[math.min(index, #cwd_group_symbols)]
    local group = {
        cwd = cwd,
        greek = symbol.greek,
        key = symbol.key,
        index = index,
    }
    cwd_groups[cwd] = group
    if index <= #cwd_group_symbols then
        cwd_groups_by_index[index] = group
    end
    next_cwd_group = next_cwd_group + 1
    return group
end

---@param key string
---@return string|nil cwd
function M.cwd_for_group_key(key)
    for index, symbol in ipairs(cwd_group_symbols) do
        if symbol.key == key then
            local group = cwd_groups_by_index[index]
            return group and group.cwd or nil
        end
    end
    return nil
end

-- Exposed read-only so tests can assert against the tracked global cwd
-- without relying on the unreliable getcwd(-1).
function M.get_global_cwd()
    return global_cwd
end

vim.api.nvim_create_autocmd("DirChanged", {
    pattern = "global",
    callback = function(args) global_cwd = vim.fs.normalize(args.file) end,
})

vim.api.nvim_create_autocmd("DirChanged", {
    pattern = "tabpage",
    callback = function(args)
        local cwd = vim.fs.normalize(args.file)
        if cwd ~= global_cwd then
            register_cwd_group(cwd)
        end
    end,
})

-- When a new tab is created from a tab with :tcd, Neovim copies the tab-local
-- directory to the new tab. Reset it back to the global cwd so new tabs always
-- start from :cd (global) rather than leaking a parent tab's :tcd.
vim.api.nvim_create_autocmd("TabNew", {
    callback = function()
        local cwd = vim.fs.normalize(vim.fn.getcwd())
        if cwd ~= global_cwd then
            vim.cmd("tcd " .. global_cwd)
        end
    end,
})

local function open_in_picked_tab(action_fn)
    local cur = vim.fn.tabpagenr()
    local result = tabprompt.prompt_for_tab({
        allow_new = true,
        getchar_prompt = "Tab (1-%d, N/A/B): ",
        input_prompt = "Tab number (or N/A/B): ",
    })
    if not result then
        return
    end
    if result.new == "end" then
        vim.cmd.tabnew()
        vim.cmd("tabmove")
    elseif result.new == "after" then
        vim.cmd.tabnew()
        vim.cmd.tabmove(tostring(cur))
    elseif result.new == "before" then
        vim.cmd.tabnew()
        vim.cmd.tabmove(tostring(cur - 1))
    else
        vim.cmd.tabnext(tostring(result.tabnr))
    end
    action_fn()
end

local function open_current_buffer_in_new_tab(before)
    local cur = before and vim.fn.tabpagenr() or nil
    local view = vim.fn.winsaveview()
    local bufname = vim.api.nvim_buf_get_name(0)
    local has_file = bufname ~= ""
    -- Save the source tab's effective cwd so we can restore it in the clone.
    -- The TabNew autocmd resets new tabs to the global cwd, which would
    -- otherwise lose a tab-local :tcd.
    local source_cwd = vim.fs.normalize(vim.fn.getcwd())

    if has_file then
        -- Open by absolute path so the buffer resolves identically regardless
        -- of the new tab's working directory. Using "%" would re-resolve the
        -- filename against the new tab's cwd and can create a duplicate buffer.
        local abs_bufname = vim.fn.fnamemodify(bufname, ":p")
        vim.cmd("tabnew " .. vim.fn.fnameescape(abs_bufname))
        vim.fn.winrestview(view)
    else
        vim.cmd.tabnew()
    end

    -- Restore the source tab's working directory in the cloned tab.
    local new_cwd = vim.fs.normalize(vim.fn.getcwd())
    if new_cwd ~= source_cwd then
        vim.cmd("tcd " .. vim.fn.fnameescape(source_cwd))
    end

    if cur then
        local target = cur - 1
        if target == 0 then
            vim.cmd.tabmove("0")
        else
            vim.cmd.tabmove(tostring(target))
        end
    end
end

local function close_tab()
    if vim.fn.tabpagenr("$") == 1 then
        print("Cannot close the last tab")
    else
        vim.cmd.tabclose()
    end
end

-- Open/close a tab
vim.keymap.set("n", "<leader>tt", function() open_current_buffer_in_new_tab(false) end)
vim.keymap.set("n", "<leader>tq", close_tab)
vim.keymap.set("n", "<leader>tc", close_tab)

-- Move current tab to a chosen position
local function prompt_move_tab()
    local last_tabnr = vim.fn.tabpagenr("$")
    if last_tabnr == 1 then
        print("Only one tab")
        return
    end

    vim.cmd("redraw")

    local result = tabprompt.prompt_for_tab({
        last_tabnr = last_tabnr,
        getchar_prompt = "Move to tab (1-%d): ",
        input_prompt = "Move to tab number: ",
        on_invalid = function() print("Invalid tab number") end,
    })

    if not result then
        return
    end

    local cur = vim.fn.tabpagenr()
    if result.tabnr == 1 then
        vim.cmd.tabmove("0")
    else
        vim.cmd.tabmove(tostring(result.tabnr <= cur and result.tabnr - 1 or result.tabnr))
    end
end

vim.keymap.set("n", "<leader>tm", prompt_move_tab)

-- Move current tab left/right
vim.keymap.set("n", "<M-{>", function()
    if vim.fn.tabpagenr() > 1 then
        vim.cmd("tabmove -1")
    end
end)

vim.keymap.set("n", "<M-}>", function()
    if vim.fn.tabpagenr() < vim.fn.tabpagenr("$") then
        vim.cmd("tabmove +1")
    end
end)

-- Open a new tab at the last, after, or before the active tab
vim.keymap.set("n", "<leader>tn", function()
    vim.cmd.tabnew()
    vim.cmd("tabmove")
end)
vim.keymap.set("n", "<leader>ta", function()
    local cur = vim.fn.tabpagenr()
    vim.cmd.tabnew()
    vim.cmd.tabmove(tostring(cur))
end)
vim.keymap.set("n", "<leader>tb", function()
    local cur = vim.fn.tabpagenr()
    vim.cmd.tabnew()
    vim.cmd.tabmove(tostring(cur - 1))
end)

-- Go to prev/next/last tab
vim.keymap.set("n", "<M-[>", vim.cmd.tabprev)
vim.keymap.set("n", "<M-]>", vim.cmd.tabnext)
vim.keymap.set("n", "<leader>tl", "g<tab>")

-- Go to tab N
local function gen_tabn(num)
    return function()
        local last_tabnr = vim.fn.tabpagenr("$")
        if num <= last_tabnr then
            vim.cmd.tabn(string.format("%d", num))
        else
            print(string.format("Tab %d does not exist", num))
        end
    end
end
vim.keymap.set("n", "<M-1>", gen_tabn(1))
vim.keymap.set("n", "<M-2>", gen_tabn(2))
vim.keymap.set("n", "<M-3>", gen_tabn(3))
vim.keymap.set("n", "<M-4>", gen_tabn(4))
vim.keymap.set("n", "<M-5>", gen_tabn(5))
vim.keymap.set("n", "<M-6>", gen_tabn(6))
vim.keymap.set("n", "<M-7>", gen_tabn(7))
vim.keymap.set("n", "<M-8>", gen_tabn(8))
vim.keymap.set("n", "<M-9>", gen_tabn(9))

local function rtl_components(dir)
    local parts = {}
    while dir ~= "" and dir ~= "." and dir ~= "/" do
        parts[#parts + 1] = vim.fn.fnamemodify(dir, ":t")
        dir = vim.fn.fnamemodify(dir, ":h")
    end
    return parts
end

local function truncate(s, max)
    if #s > max then
        return s:sub(1, max - 3) .. "..."
    end
    return s
end

local last_normal_win = {}

vim.api.nvim_create_autocmd("WinEnter", {
    group = vim.api.nvim_create_augroup("TabLabelTracking", { clear = true }),
    callback = function()
        local winid = vim.api.nvim_get_current_win()
        local cfg = vim.api.nvim_win_get_config(winid)
        if cfg.relative == "" then
            last_normal_win[vim.fn.tabpagenr()] = winid
        end
    end,
})

do
    local winid = vim.api.nvim_get_current_win()
    local cfg = vim.api.nvim_win_get_config(winid)
    if cfg.relative == "" then
        last_normal_win[vim.fn.tabpagenr()] = winid
    end
end

local function tab_label(tabpage, tabnr)
    local cur_winid = vim.api.nvim_tabpage_get_win(tabpage)
    local cfg = vim.api.nvim_win_get_config(cur_winid)
    local bufnr

    if cfg.relative == "" then
        local b = vim.api.nvim_win_get_buf(cur_winid)
        if b and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype ~= "terminal" then
            bufnr = b
        end
    end

    if not bufnr then
        local tracked = last_normal_win[tabnr]
        if tracked and vim.api.nvim_win_is_valid(tracked) then
            local tcfg = vim.api.nvim_win_get_config(tracked)
            if tcfg.relative == "" then
                local b = vim.api.nvim_win_get_buf(tracked)
                if b and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype ~= "terminal" then
                    bufnr = b
                end
            end
        end
    end

    if not bufnr then
        for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            local wcfg = vim.api.nvim_win_get_config(winid)
            if wcfg.relative == "" then
                local b = vim.api.nvim_win_get_buf(winid)
                if b and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype ~= "terminal" then
                    bufnr = b
                    break
                end
            end
        end
    end

    if not bufnr then
        local buflist = vim.fn.tabpagebuflist(tabnr)
        local winnr = vim.fn.tabpagewinnr(tabnr)
        bufnr = buflist[winnr]
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)

    if bufname == "" then
        return "[No Name]"
    end

    local tail = vim.fn.fnamemodify(bufname, ":t")

    local all = {}
    for t = 1, vim.fn.tabpagenr("$") do
        local bl = vim.fn.tabpagebuflist(t)
        local name = vim.api.nvim_buf_get_name(bl[vim.fn.tabpagewinnr(t)])
        if name ~= "" then
            all[#all + 1] = name
        end
    end

    local group = {}
    for _, p in ipairs(all) do
        if vim.fn.fnamemodify(p, ":t") == tail then
            group[#group + 1] = p
        end
    end

    if #group <= 1 then
        return truncate(tail, 27)
    end

    local comps, max = {}, 0
    for i, p in ipairs(group) do
        comps[i] = rtl_components(vim.fn.fnamemodify(p, ":h"))
        if #comps[i] > max then
            max = #comps[i]
        end
    end

    local col = 0
    while col < max do
        local first
        local same = true
        for _, parts in ipairs(comps) do
            local v = parts[col + 1]
            if v ~= nil then
                if first == nil then
                    first = v
                elseif v ~= first then
                    same = false
                    break
                end
            end
        end
        if not same then
            break
        end
        col = col + 1
    end

    local idx
    for i, p in ipairs(group) do
        if p == bufname then
            idx = i
            break
        end
    end

    local prefix = idx and col < max and comps[idx][col + 1]
    return truncate(prefix and (prefix .. ":" .. tail) or tail, 27)
end

local function tab_str(tabnr, label, active)
    local hl = active and "%#TabLineSel#" or "%#TabLine#"
    return string.format("%%%dT%s %d %s%s %%#TabLine#", tabnr, hl, tabnr, hl, label)
end

local function tab_width(tabnr, label)
    return 1 + vim.fn.strdisplaywidth(tostring(tabnr)) + 1 + vim.fn.strdisplaywidth(label) + 1
end

local function _scrolled_range(tabs, total, cur, cols)
    if #tabs == 0 or total == 0 then
        return { start = 1, end_ = 1, left_arrow = false, right_arrow = false }
    end

    -- Total width if all tabs are rendered
    local total_w = tabs[1].w
    for tabnr = 2, total do
        total_w = total_w + 1 + tabs[tabnr].w
    end

    if total_w <= cols then
        return { start = 1, end_ = total, left_arrow = false, right_arrow = false }
    end

    local avail = cols
    local s, e = cur, cur
    local w = tabs[cur].w

    -- Phase 1: first include up to 2 tabs on each side of the active tab
    for _ = 1, 2 do
        if e < total and w + 1 + tabs[e + 1].w <= avail then
            e = e + 1
            w = w + 1 + tabs[e].w
        end
        if s > 1 and w + 1 + tabs[s - 1].w <= avail then
            s = s - 1
            w = w + 1 + tabs[s].w
        end
    end

    -- Phase 2: expand further outward while space allows
    while true do
        local changed = false
        while e < total and w + 1 + tabs[e + 1].w <= avail do
            e = e + 1
            w = w + 1 + tabs[e].w
            changed = true
        end
        while s > 1 and w + 1 + tabs[s - 1].w <= avail do
            s = s - 1
            w = w + 1 + tabs[s].w
            changed = true
        end
        if not changed then
            break
        end
    end

    -- Phase 3: reserve space for scroll indicators
    local left_arrow = s > 1
    local right_arrow = e < total
    if left_arrow then
        avail = avail - 3
    end
    if right_arrow then
        avail = avail - 3
    end

    -- Phase 4: retract tabs from the furthest side to fit arrows
    while w > avail and s < e do
        if cur - s <= e - cur then
            w = w - (1 + tabs[e].w)
            e = e - 1
        else
            w = w - (1 + tabs[s].w)
            s = s + 1
        end
    end
    left_arrow = s > 1
    right_arrow = e < total

    return { start = s, end_ = e, left_arrow = left_arrow, right_arrow = right_arrow }
end

local function tabline()
    local total = vim.fn.tabpagenr("$")
    local cur = vim.fn.tabpagenr()
    local cols = vim.o.columns

    local tabpages = vim.api.nvim_list_tabpages()
    local tabs = {}
    for tabnr = 1, total do
        local label = tab_label(tabpages[tabnr], tabnr)
        -- Mark tabs whose tab-local cwd belongs to a tracked group. A cwd
        -- that predates this module's DirChanged handler is intentionally
        -- left unmarked.
        local tcwd = vim.fs.normalize(vim.fn.getcwd(-1, tabnr))
        if tcwd ~= global_cwd then
            local group = cwd_groups[tcwd]
            if group then
                label = label .. group.greek
            end
        end
        tabs[tabnr] = {
            label = label,
            w = tab_width(tabnr, label),
        }
    end

    -- Total width if all tabs are rendered
    local total_w = tabs[1].w
    for tabnr = 2, total do
        total_w = total_w + 1 + tabs[tabnr].w
    end

    if total_w <= cols then
        local parts = {}
        for tabnr = 1, total do
            if tabnr > 1 then
                table.insert(parts, "%#TabLineFill#|")
            end
            table.insert(parts, tab_str(tabnr, tabs[tabnr].label, tabnr == cur))
        end
        table.insert(parts, "%#TabLineFill#%T")
        return table.concat(parts)
    end

    local range = _scrolled_range(tabs, total, cur, cols)

    local parts = {}
    if range.left_arrow then
        table.insert(parts, "%#TabLineFill# < ")
    end
    for tabnr = range.start, range.end_ do
        if tabnr > range.start then
            table.insert(parts, "%#TabLineFill#|")
        end
        table.insert(parts, tab_str(tabnr, tabs[tabnr].label, tabnr == cur))
    end
    if range.right_arrow then
        table.insert(parts, "%#TabLineFill# > ")
    end
    table.insert(parts, "%#TabLineFill#%T")
    return table.concat(parts)
end

--- Truncate a path to at most `max` characters, eliding the head with "...".
---@param path string
---@param max integer
---@return string
function M.truncate_path(path, max)
    if #path <= max then
        return path
    end
    return "..." .. path:sub(#path - (max - 3) + 1)
end

--- Tab-local working directory segment for the statusline. Always shown for
--- the current tab (even when it equals the global cwd), truncated to `max`
--- characters and marked with a trailing "%" when it differs from global.
---@param max integer|nil
---@return string
function M.twd_statusline(max)
    max = max or 30
    local cwd = vim.fs.normalize(vim.fn.getcwd())
    local s = M.truncate_path(cwd, max)
    if cwd ~= global_cwd then
        s = s .. "%"
    end
    return s
end

M.open_in_picked_tab = open_in_picked_tab
M._open_current_buffer_in_new_tab = open_current_buffer_in_new_tab
M._scrolled_range = _scrolled_range
M.tabline = tabline

function M._reset_cwd_groups()
    cwd_groups = {}
    cwd_groups_by_index = {}
    next_cwd_group = 1
end

vim.o.tabline = "%!v:lua.require'ytret.tabs'.tabline()"

-- Statusline: buffer info on the left, the tab-local working directory and
-- the default ruler info on the right.
vim.o.statusline = "%f %h%m%r%=%{v:lua.require'ytret.tabs'.twd_statusline(30)}  %l:%c %p%%"

return M
