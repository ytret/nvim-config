local M = {}

local fzf_actions = require("fzf-lua.actions")
local fzf_path = require("fzf-lua.path")
local fzf_utils = require("fzf-lua.utils")
local tabs = require("ytret.tabs")
local window_picker = require("yt-window-picker")
local yt_path = require("ytret.path")
local uv = vim.uv or vim.loop

local function has_real_target(selected, action_opts)
    if not selected or not selected[1] or selected[1] == "" then
        return false
    end

    local ok, entry = pcall(fzf_path.entry_to_file, selected[1], action_opts, action_opts._uri)
    if not ok or not entry then
        return false
    end

    if entry.uri then
        return true
    end

    if entry.bufnr and vim.api.nvim_buf_is_valid(entry.bufnr) then
        return true
    end

    local fullpath = entry.bufname or entry.path
    if not fullpath or fullpath == "" then
        return false
    end

    if not fzf_path.is_absolute(fullpath) then
        fullpath = fzf_path.join({
            action_opts.cwd or action_opts._cwd or fzf_utils.cwd(),
            fullpath,
        })
    end

    return uv.fs_stat(fullpath) ~= nil
end

local function with_picked_window(open_action)
    return function(selected, action_opts)
        if not has_real_target(selected, action_opts) then
            return
        end

        local target = window_picker.pick_window()
        if not target then
            return
        end

        vim.api.nvim_set_current_win(target)
        open_action(selected, action_opts)
    end
end

local function with_picked_tab(open_action)
    return function(selected, action_opts)
        if not has_real_target(selected, action_opts) then
            return
        end
        tabs.open_in_picked_tab(function()
            open_action(selected, action_opts)
        end)
    end
end

local function lsp_file_edit_prefer_rel(selected, action_opts)
    if not selected or #selected ~= 1 then
        return fzf_actions.file_edit(selected, action_opts)
    end

    local ok, entry = pcall(fzf_path.entry_to_file, selected[1], action_opts, action_opts._uri)
    if not ok or not entry then
        return fzf_actions.file_edit(selected, action_opts)
    end

    local abs_path
    if entry.uri and entry.uri:match("^file://") then
        abs_path = vim.uri_to_fname(entry.uri)
    elseif entry.path and fzf_path.is_absolute(entry.path) then
        abs_path = entry.path
    end

    if not abs_path or abs_path == "" then
        return fzf_actions.file_edit(selected, action_opts)
    end

    if not fzf_utils.is_term_buffer(0) then
        vim.cmd("normal! m`")
    end

    local target_bufnr = yt_path.bufadd_prefer_rel(abs_path)
    if target_bufnr == 0 or not yt_path.set_buf_listed(target_bufnr) then
        return fzf_actions.file_edit(selected, action_opts)
    end

    if entry.line > 0 or entry.col > 0 then
        pcall(vim.api.nvim_win_set_cursor, 0, {
            math.max(1, entry.line),
            math.max(0, entry.col - 1),
        })
    end

    if not action_opts.no_action_zz and not fzf_utils.is_term_buffer(0) then
        vim.cmd("norm! zvzz")
    end
end

function M.setup(opts)
    opts = opts or {}
    opts.fzf_colors = true
    opts.files = vim.tbl_deep_extend("force", opts.files or {}, {
        fzf_opts = {
            ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-files-history",
        },
        actions = {
            ["default"] = with_picked_window(fzf_actions.file_edit),
            ["ctrl-t"] = with_picked_tab(fzf_actions.file_edit),
        },
    })
    opts.buffers = vim.tbl_deep_extend("force", opts.buffers or {}, {
        actions = {
            ["default"] = with_picked_window(fzf_actions.file_edit),
            ["ctrl-t"] = with_picked_tab(fzf_actions.file_edit),
        },
    })
    opts.grep = vim.tbl_deep_extend("force", opts.grep or {}, {
        fzf_opts = {
            ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-grep-history",
        },
        actions = {
            ["default"] = with_picked_window(fzf_actions.file_edit),
            ["ctrl-t"] = with_picked_tab(fzf_actions.file_edit),
        },
    })
    opts.lsp = vim.tbl_deep_extend("force", opts.buffers or {}, {
        jump1_action = lsp_file_edit_prefer_rel,
        actions = {
            ["enter"] = lsp_file_edit_prefer_rel,
            ["ctrl-t"] = with_picked_tab(lsp_file_edit_prefer_rel),
        },
        document_symbols = {
            actions = {
                ["ctrl-t"] = with_picked_tab(lsp_file_edit_prefer_rel),
            },
        },
        workspace_symbols = {
            actions = {
                ["ctrl-t"] = with_picked_tab(lsp_file_edit_prefer_rel),
            },
        },
        finder = {
            actions = {
                ["ctrl-t"] = with_picked_tab(lsp_file_edit_prefer_rel),
            },
        },
    })
    opts.diagnostics = vim.tbl_deep_extend("force", opts.diagnostics or {}, {
        actions = {
            ["default"] = with_picked_window(fzf_actions.file_edit),
            ["ctrl-t"] = with_picked_tab(fzf_actions.file_edit),
        },
    })

    return opts
end

return M
