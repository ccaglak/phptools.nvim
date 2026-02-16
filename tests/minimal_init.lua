local ensure_install = function(plugin)
  local base_dir = os.getenv("BASE_DIR") or vim.fn.stdpath("data") .. "/site/pack/test/start/"
  local plugin_name = vim.split(plugin, "/")[2]

  local plugin_dir = base_dir .. plugin_name

  local plugin_not_exists = vim.fn.isdirectory(plugin_dir) == 0
  if plugin_not_exists then
    print("[INFO] Installing " .. plugin_name .. " to " .. plugin_dir)
    vim.fn.system({ "git", "clone", "https://github.com/" .. plugin, plugin_dir })
  end

  vim.opt.runtimepath:prepend(plugin_dir)
end

vim.opt.runtimepath:prepend(".")

ensure_install("nvim-lua/plenary.nvim")
ensure_install("nvim-treesitter/nvim-treesitter")

local parsers_to_install = { "php", "html", "blade", "php_only", "json" }
local ts_parsers = require("nvim-treesitter.parsers")
for _, parser in ipairs(parsers_to_install) do
  if not ts_parsers.has_parser(parser) then
    require("nvim-treesitter.install").commands.TSInstallSync["run"](parser)
  end
end

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")

local root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/tests")


_G.PHP_ROOT_MARKERS = { ".git", "composer.json", ".env" }

-- Initialize phptools
require("phptools").setup({
  ui = {
    enable = true,
    fzf = false,
  },
  custom_toggles = {
    enable = false,
  },
  php_gf = {
    enable = true,
  },
  larago = {
    enable = true,
  },
})

dd = function(xxx)
  print(vim.inspect(xxx))
end
