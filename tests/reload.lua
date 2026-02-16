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

ensure_install("nvim-lua/plenary.nvim")
ensure_install("nvim-treesitter/nvim-treesitter")

-- Install required treesitter parsers for comprehensive test scenarios
local parsers_to_install = { "php", "html", "blade", "php_only", "json" }
local ts_parsers = require("nvim-treesitter.parsers")
for _, parser in ipairs(parsers_to_install) do
  if not ts_parsers.has_parser(parser) then
    require("nvim-treesitter.install").commands.TSInstallSync["run"](parser)
  end
end

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")

local root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h")
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

-- Initialize Intelephense LSP for method generation tests using vim.lsp.config
local function setup_lsp()
  -- Use Neovim's native LSP config API
  if vim.lsp.config then
    vim.lsp.config("intelephense", {
      cmd = { "intelephense", "--stdio" },
      root_markers = { "composer.json", ".git" },
      filetypes = { "php", "blade" },
      capabilities = {
        textDocument = {
          formatting = {
            dynamicRegistration = false,
          },
        },
      },
      settings = {
        intelephense = {
          format = {
            braces = "psr12",
          },
          phpdoc = {
            textFormat = "text",
            functionTemplate = {
              summary = "$1",
              tags = {
                "@param ${1:$SYMBOL_TYPE} $SYMBOL_NAME",
                "@return ${1:$SYMBOL_TYPE}",
                "@throws ${1:$SYMBOL_TYPE}",
              },
            },
          },
        },
      },
    })

    -- Enable the Intelephense LSP server
    if vim.lsp.enable then
      vim.lsp.enable("intelephense")
      print("[INFO] Intelephense LSP enabled")
    end
  end
end

-- Setup LSP but don't fail tests if it's not available
pcall(setup_lsp)
