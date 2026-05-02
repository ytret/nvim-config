local fzf = require("fzf-lua")

-- Session/project-scope commands
vim.keymap.set("n", "<M-p>", fzf.buffers, {})
vim.keymap.set("n", "<C-p>", fzf.files, {})
vim.keymap.set("n", "<C-k>", function() fzf.files({ no_ignore = true }) end, {})
vim.keymap.set("n", "<leader>ps", fzf.live_grep, {})
vim.keymap.set("n", "<leader>pa", function() fzf.live_grep({ no_ignore = true }) end, {})
vim.keymap.set("n", "<leader><M-p>", fzf.resume, {})
vim.keymap.set("n", "<leader><C-p>", fzf.resume, {})
vim.keymap.set("n", "<leader>pr", fzf.resume, {})

-- LSP: project-scope
vim.keymap.set("n", "<M-f>", fzf.lsp_finder)
vim.keymap.set("n", "<leader>sw", fzf.lsp_live_workspace_symbols, {})
vim.keymap.set("n", "<leader>dw", fzf.lsp_workspace_diagnostics, {})

-- LSP: buffer-scope
vim.keymap.set("n", "<leader>sd", fzf.lsp_document_symbols, {})
vim.keymap.set("n", "<leader>dd", fzf.lsp_document_diagnostics, {})

-- LSP: cursor-scope
vim.keymap.set("n", "gd", fzf.lsp_definitions, {})
vim.keymap.set("n", "<leader>vrt", fzf.lsp_typedefs, {})
vim.keymap.set("n", "<leader>vrr", fzf.lsp_references, {})
vim.keymap.set("n", "<leader>vrc", fzf.lsp_incoming_calls, {})
vim.keymap.set("n", "<leader>vro", fzf.lsp_outgoing_calls, {})
