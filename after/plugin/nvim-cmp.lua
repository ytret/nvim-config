local cmp = require("cmp")
local types = require("cmp.types")

cmp.setup({
    sources = {
        {
            name = "nvim_lsp",
            entry_filter = function(entry, _)
                return types.lsp.CompletionItemKind[entry:get_kind()] ~= "Text"
            end,
        },
    },
})
