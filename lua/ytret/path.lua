local M = {}

local uv = vim.uv or vim.loop

local function canonical_path(path) return uv.fs_realpath(path) or vim.fs.normalize(path) end

local function find_buffer_by_path(path)
    local target = canonical_path(path)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" and canonical_path(name) == target then
            return bufnr
        end
    end
end

local function is_buffer_visible(bufnr)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == bufnr then
            return true
        end
    end
    return false
end

local function can_buffer_be_reused(bufnr, rel_path)
    return rel_path == nil
        or vim.fn.buflisted(bufnr) == 1
        or vim.bo[bufnr].modified
        or is_buffer_visible(bufnr)
end

function M.bufadd_prefer_rel(abs_path)
    local rel_path = vim.fs.relpath(vim.fn.getcwd(), abs_path)
    local target_path = rel_path or abs_path
    local existing_bufnr = find_buffer_by_path(abs_path)

    if existing_bufnr ~= nil then
        if vim.api.nvim_buf_get_name(existing_bufnr) == target_path then
            return existing_bufnr
        end

        if can_buffer_be_reused(existing_bufnr, rel_path) then
            return existing_bufnr
        end

        vim.api.nvim_buf_delete(existing_bufnr, { force = true })
    end

    local bufnr = vim.fn.bufadd(target_path)
    if bufnr ~= -1 then
        return bufnr
    end

    if rel_path ~= nil then
        bufnr = vim.fn.bufadd(abs_path)
        if bufnr ~= -1 then
            return bufnr
        end
    end

    return 0
end

function M.set_buf_listed(bufnr)
    vim.cmd.stopinsert()
    local ok = pcall(vim.api.nvim_set_current_buf, bufnr)
    if not ok then
        return false
    end

    vim.bo[bufnr].buflisted = true
    return true
end

function M.path_prefer_rel(abs_path)
    local rel_path = vim.fs.relpath(vim.fn.getcwd(), abs_path)
    return rel_path or abs_path
end

return M
