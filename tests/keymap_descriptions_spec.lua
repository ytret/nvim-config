-- Capture registrations without loading plugins or changing live mappings.
local function load_mappings(path)
    local mappings = {}
    local attach
    local noop = function() end
    local plugin = setmetatable({ formatters = {} }, { __index = function() return noop end })
    local api = setmetatable({
        nvim_create_autocmd = function(event, opts)
            if event == "LspAttach" then
                attach = opts.callback
            end
        end,
    }, { __index = vim.api })
    local fake_vim = setmetatable({
        g = {},
        o = {},
        api = api,
        keymap = {
            set = function(mode, lhs, rhs, opts)
                mappings[#mappings + 1] = { mode = mode, lhs = lhs, rhs = rhs, opts = opts }
            end,
        },
        lsp = setmetatable({
            config = noop,
            get_client_by_id = function() return { name = "clangd" } end,
        }, { __index = vim.lsp }),
    }, { __index = vim })
    local chunk = assert(loadfile(path))
    setfenv(
        chunk,
        setmetatable({
            vim = fake_vim,
            require = function() return plugin end,
        }, { __index = _G })
    )
    chunk()
    if attach then
        attach({ buf = 42, data = { client_id = 1 } })
    end
    return mappings
end

local function assert_descriptions(mappings)
    assert.is_true(#mappings > 0)
    for _, mapping in ipairs(mappings) do
        assert.equals("string", type(mapping.opts and mapping.opts.desc), mapping.lhs)
        assert.is_true(#mapping.opts.desc > 0, mapping.lhs)
    end
end

describe("keymap descriptions", function()
    it(
        "describes general mappings",
        function() assert_descriptions(load_mappings("lua/ytret/remap.lua")) end
    )

    it(
        "describes generated tab and working-directory group mappings",
        function() assert_descriptions(load_mappings("lua/ytret/tabs.lua")) end
    )

    it(
        "describes directory prompt shortcuts",
        function() assert_descriptions(load_mappings("lua/ytret/cwd.lua")) end
    )

    for _, name in ipairs({
        "fzf",
        "git-blame",
        "lazygit",
        "luasnip",
        "treesitter-textobjects",
        "undotree",
        "conform",
    }) do
        it(
            "describes " .. name .. " mappings",
            function() assert_descriptions(load_mappings("after/plugin/" .. name .. ".lua")) end
        )
    end

    it("describes LSP mappings and preserves buffer-local nonrecursive options", function()
        local mappings = load_mappings("after/plugin/lsp.lua")
        assert_descriptions(mappings)
        local descriptions = {}
        for _, mapping in ipairs(mappings) do
            assert.equals(42, mapping.opts.buffer)
            assert.is_false(mapping.opts.remap)
            descriptions[mapping.lhs] = mapping.opts.desc
        end
        assert.equals("Definition in tab 1", descriptions.gt1)
        assert.equals("Definition in tab 9", descriptions.gt9)
        assert.equals("Previous diagnostic", descriptions["[d"])
        assert.equals("Next diagnostic", descriptions["]d"])
    end)
end)
