local mock_fzf = {
    buffers = function() end,
    files = function() end,
    live_grep = function() end,
    resume = function() end,
    lgrep_curbuf = function() end,
    grep_curbuf = function() end,
    lsp_finder = function() end,
    lsp_live_workspace_symbols = function() end,
    lsp_workspace_diagnostics = function() end,
    lsp_document_symbols = function() end,
    lsp_document_diagnostics = function() end,
    lsp_definitions = function() end,
    lsp_typedefs = function() end,
    lsp_references = function() end,
    lsp_incoming_calls = function() end,
    lsp_outgoing_calls = function() end,
}

local function leader_pf_map()
    local lhs = vim.api.nvim_replace_termcodes("<leader>pf", true, false, true)
    return vim.fn.maparg(lhs, "n", false, true)
end

describe("fzf current-file grep keymap", function()
    before_each(function()
        package.loaded["fzf-lua"] = mock_fzf
        vim.g.mapleader = " "
        dofile("after/plugin/fzf.lua")
    end)

    after_each(function()
        pcall(vim.keymap.del, "n", "<leader>pf")
        vim.g.mapleader = nil
    end)

    it("binds <leader>pf to a Lua callback", function()
        local map = leader_pf_map()
        assert.is_table(map)
        assert.is_function(map.callback)
    end)

    it("runs live grep of the current buffer", function()
        local called_with
        mock_fzf.lgrep_curbuf = function(opts) called_with = opts end
        local map = leader_pf_map()
        map.callback()
        assert.is_table(called_with)
    end)

    it("passes --no-sort so results keep line-number order", function()
        local called_with
        mock_fzf.lgrep_curbuf = function(opts) called_with = opts end
        local map = leader_pf_map()
        map.callback()
        assert.is_true(called_with.fzf_opts["--no-sort"])
    end)
end)
