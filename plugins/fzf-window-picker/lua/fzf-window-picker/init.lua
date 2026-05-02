local M = {}
local prompt = "Pick window: "

local function index_to_label(index)
    local label = ""

    while index > 0 do
        local remainder = (index - 1) % 26
        label = string.char(65 + remainder) .. label
        index = math.floor((index - 1) / 26)
    end

    return label
end

local function list_normal_windows()
    local windows = {}

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative == "" and config.focusable and not config.hide and not config.external then
            table.insert(windows, win)
        end
    end

    return windows
end

local function clear_prompt()
    if vim.opt.cmdheight._value ~= 0 then
        vim.cmd("normal! :")
    end
end

local function leave_terminal_mode()
    local mode = vim.api.nvim_get_mode().mode
    if mode == "t" then
        local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
        vim.api.nvim_feedkeys(keys, "n", false)
        vim.cmd("redraw")
    end
end

local function draw_labels(windows)
    local labels = {}
    local window_options = {}
    local laststatus = vim.o.laststatus
    local fillchars = vim.opt.fillchars:get()
    local original_stl = fillchars.stl
    local original_stlnc = fillchars.stlnc

    vim.o.laststatus = 2
    fillchars.stl = nil
    fillchars.stlnc = nil
    vim.opt.fillchars = fillchars

    for index, win in ipairs(windows) do
        local label = index_to_label(index)
        local ok_statusline, statusline = pcall(vim.api.nvim_get_option_value, "statusline", { win = win })
        local ok_winhl, winhl = pcall(vim.api.nvim_get_option_value, "winhl", { win = win })

        window_options[win] = {
            statusline = ok_statusline and statusline or "",
            winhl = ok_winhl and winhl or "",
        }

        labels[label] = win
        vim.api.nvim_set_option_value("statusline", "%=" .. label .. "%=", { win = win })
        vim.api.nvim_set_option_value("winhl", "StatusLine:ErrorMsg,StatusLineNC:ErrorMsg", { win = win })
    end

    fillchars.stl = original_stl
    fillchars.stlnc = original_stlnc

    return labels, window_options, laststatus, fillchars
end

local function clear_labels(window_options, laststatus, fillchars)
    for win, options in pairs(window_options) do
        if vim.api.nvim_win_is_valid(win) then
            for option, value in pairs(options) do
                vim.api.nvim_set_option_value(option, value, { win = win })
            end
        end
    end

    vim.o.laststatus = laststatus
    vim.opt.fillchars = fillchars
end

local function get_user_input()
    local char = vim.fn.getchar()
    while type(char) ~= "number" do
        char = vim.fn.getchar()
    end
    return char, vim.fn.nr2char(char)
end

function M.pick_window()
    leave_terminal_mode()

    local windows = list_normal_windows()

    if #windows == 0 then
        return nil
    end

    if #windows == 1 then
        return windows[1]
    end

    local labels, window_options, laststatus, fillchars = draw_labels(windows)
    vim.cmd("redraw")

    if vim.opt.cmdheight._value ~= 0 then
        print(prompt)
    end

    while true do
        local ok, code, input = pcall(function()
            local key_code, key = get_user_input()
            return key_code, key
        end)

        if not ok then
            clear_labels(window_options, laststatus, fillchars)
            clear_prompt()
            vim.cmd("redraw")
            return nil
        end

        local normalized = vim.trim(input):upper()
        if code == 3 or code == 27 then
            clear_labels(window_options, laststatus, fillchars)
            clear_prompt()
            vim.cmd("redraw")
            return nil
        end

        if labels[normalized] then
            clear_labels(window_options, laststatus, fillchars)
            clear_prompt()
            vim.cmd("redraw")
            return labels[normalized]
        end
    end
end

return M
