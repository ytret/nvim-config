local M = {}

M._getchar = vim.fn.getchar
M._input = vim.fn.input
M._nr2char = vim.fn.nr2char
M._cmdheight = function() return vim.opt.cmdheight._value end
M._print = print

function M.prompt_for_tab(opts)
    opts = opts or {}
    local last_tabnr = opts.last_tabnr or vim.fn.tabpagenr("$")
    local allow_new = opts.allow_new
    local getchar_prompt = opts.getchar_prompt or "Tab (1-%d): "
    local input_prompt = opts.input_prompt or "Tab number: "
    local on_new = opts.on_new
    local on_invalid = opts.on_invalid

    if last_tabnr <= 9 then
        if M._cmdheight() ~= 0 then
            M._print(string.format(getchar_prompt, last_tabnr))
        end
        while true do
            local ok, code = pcall(M._getchar)
            if not ok or type(code) ~= "number" then
                return nil
            end
            if code == 27 or code == 3 then
                return nil
            end
            local char = M._nr2char(code)
            if allow_new and char:upper() == "N" then
                if on_new then
                    on_new()
                end
                return { new = true }
            end
            local n = tonumber(char)
            if n and n >= 1 and n <= last_tabnr then
                return { tabnr = n }
            end
        end
    else
        local ok, input = pcall(M._input, input_prompt)
        if not ok or input == "" then
            return nil
        end
        if allow_new then
            local upper = input:upper()
            if upper == "N" then
                if on_new then
                    on_new()
                end
                return { new = true }
            end
        end
        local n = tonumber(input)
        if not n or n < 1 or n > last_tabnr then
            if on_invalid then
                on_invalid()
            end
            return nil
        end
        return { tabnr = n }
    end
end

return M

