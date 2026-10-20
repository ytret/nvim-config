local fzf = require("fzf-lua")

-- Session/project-scope commands
vim.keymap.set("n", "<M-p>", fzf.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<C-p>", fzf.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>ps", fzf.live_grep, { desc = "Live grep project" })
vim.keymap.set("n", "<leader>pr", fzf.resume, { desc = "Resume last picker" })

-- Current-file scope: live grep the opened file, results in line-number order
vim.keymap.set(
    "n",
    "<leader>pf",
    function() fzf.lgrep_curbuf({ fzf_opts = { ["--no-sort"] = true } }) end,
    { desc = "Live grep current file (sorted by line)" }
)

-- LSP: project-scope
vim.keymap.set("n", "<M-f>", fzf.lsp_finder, { desc = "Find LSP locations" })
vim.keymap.set(
    "n",
    "<leader>sw",
    fzf.lsp_live_workspace_symbols,
    { desc = "Search workspace symbols" }
)
vim.keymap.set("n", "<leader>dw", fzf.lsp_workspace_diagnostics, { desc = "Workspace diagnostics" })

-- LSP: buffer-scope
vim.keymap.set("n", "<leader>sd", fzf.lsp_document_symbols, { desc = "Document symbols" })
vim.keymap.set("n", "<leader>dd", fzf.lsp_document_diagnostics, { desc = "Document diagnostics" })

-- LSP: cursor-scope
vim.keymap.set("n", "gd", fzf.lsp_definitions, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>vrt", fzf.lsp_typedefs, { desc = "Go to type definition" })
vim.keymap.set("n", "<leader>vrr", fzf.lsp_references, { desc = "Find references" })
vim.keymap.set("n", "<leader>vrc", fzf.lsp_incoming_calls, { desc = "Incoming calls" })
vim.keymap.set("n", "<leader>vro", fzf.lsp_outgoing_calls, { desc = "Outgoing calls" })
