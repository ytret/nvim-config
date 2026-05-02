local M = {}

local fzf_actions = require("fzf-lua.actions")
local fzf_path = require("fzf-lua.path")
local fzf_utils = require("fzf-lua.utils")
local window_picker = require("fzf-window-picker")
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

function M.setup(opts)
    opts = opts or {}
    opts.fzf_colors = true
    opts.files = vim.tbl_deep_extend("force", opts.files or {}, {
        fzf_opts = {
            ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-files-history",
        },
        actions = {
            ["default"] = with_picked_window(fzf_actions.file_edit),
        },
    })
    opts.buffers = vim.tbl_deep_extend("force", opts.buffers or {}, {
        actions = {
            ["default"] = with_picked_window(fzf_actions.buf_edit),
        },
    })
    opts.grep = vim.tbl_deep_extend("force", opts.grep or {}, {
        fzf_opts = {
            ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-grep-history",
        },
        actions = {
            ["default"] = with_picked_window(fzf_actions.file_edit),
        },
    })

    return opts
end

return M
