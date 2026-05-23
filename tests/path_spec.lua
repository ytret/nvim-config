local path = require("ytret.path")

describe("bufadd_prefer_rel", function()
    local tmpdir
    local abs_path

    before_each(function()
        local keep = vim.api.nvim_get_current_buf()
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= keep and vim.api.nvim_buf_is_valid(b) then
                vim.api.nvim_buf_delete(b, { force = true })
            end
        end

        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        local sub = tmpdir .. "/sub"
        vim.fn.mkdir(sub, "p")
        abs_path = sub .. "/test.lua"
        vim.fn.writefile({}, abs_path)
        vim.fn.chdir(tmpdir)
    end)

    after_each(function()
        vim.fn.chdir(vim.env.HOME or "/")
        if tmpdir and vim.fn.isdirectory(tmpdir) == 1 then
            vim.fn.delete(tmpdir, "rf")
        end
    end)

    describe("when existing buffer is found", function()
        it("returns it if name matches target_path", function()
            local bufnr = vim.fn.bufadd("sub/test.lua")
            vim.bo[bufnr].buflisted = true

            assert.equals(bufnr, path.bufadd_prefer_rel(abs_path))
        end)

        it("deletes and re-adds if name mismatch and buffer is deletable", function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(bufnr, abs_path)
            vim.bo[bufnr].buflisted = false
            vim.bo[bufnr].modified = false

            local result = path.bufadd_prefer_rel(abs_path)
            assert.falsy(vim.api.nvim_buf_is_valid(bufnr))
            assert.is_true(result > 0)
        end)

        it("returns existing if listed", function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(bufnr, abs_path)
            vim.bo[bufnr].buflisted = true

            assert.equals(bufnr, path.bufadd_prefer_rel(abs_path))
        end)

        it("returns existing if modified", function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(bufnr, abs_path)
            vim.bo[bufnr].buflisted = false
            vim.bo[bufnr].modified = true

            assert.equals(bufnr, path.bufadd_prefer_rel(abs_path))
        end)

        it("returns existing if visible in a window", function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(bufnr, abs_path)
            vim.bo[bufnr].buflisted = false
            vim.bo[bufnr].modified = false
            vim.api.nvim_set_current_buf(bufnr)

            assert.equals(bufnr, path.bufadd_prefer_rel(abs_path))
        end)
    end)

    describe("when no existing buffer is found", function()
        it("creates a new buffer for the path", function()
            local result = path.bufadd_prefer_rel(abs_path)
            assert.is_true(result > 0)
            assert.is_true(vim.api.nvim_buf_is_valid(result))
        end)
    end)
end)

describe("set_buf_listed", function()
    local path = require("ytret.path")

    it("stops insert mode and marks buffer as listed", function()
        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].buflisted = false
        vim.cmd.startinsert()

        local result = path.set_buf_listed(bufnr)

        assert.is_true(result)
        assert.is_true(vim.bo[bufnr].buflisted)
        assert.equals(bufnr, vim.api.nvim_get_current_buf())
        assert.equals("n", vim.fn.mode())
    end)

    it("returns false for nil bufnr", function()
        local result = path.set_buf_listed(nil)
        assert.is_false(result)
    end)

    it("returns false for invalid bufnr", function()
        local result = path.set_buf_listed(99999)
        assert.is_false(result)
    end)
end)
