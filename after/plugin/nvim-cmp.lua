local cmp = require("cmp")
local types = require("cmp.types")

local cmp_select = { behavior = cmp.SelectBehavior.Select }

local function select_next()
    if cmp.visible() then
        cmp.select_next_item(cmp_select)
    else
        cmp.complete()
    end
end

local function select_prev()
    if cmp.visible() then
        cmp.select_prev_item(cmp_select)
    else
        cmp.complete()
    end
end

cmp.setup({
    snippet = {
        expand = function(args) require("luasnip").lsp_expand(args.body) end,
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),

        ["<C-p>"] = cmp.mapping(select_prev, { "i" }),
        ["<C-n>"] = cmp.mapping(select_next, { "i" }),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<C-y>"] = cmp.mapping.confirm({ select = true }),

        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
    }),
    sources = cmp.config.sources({
        {
            name = "nvim_lsp",
            entry_filter = function(entry, _)
                return types.lsp.CompletionItemKind[entry:get_kind()] ~= "Text"
            end,
        },
        { name = "nvim_lua" },
    }),
})
