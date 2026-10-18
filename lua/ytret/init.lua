vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

pcall(require, "ytret.local-pre")

require("ytret.remap")
require("ytret.lazy")
require("ytret.set")
require("ytret.tabs")
require("ytret.cwd")

pcall(require, "ytret.local-post")
