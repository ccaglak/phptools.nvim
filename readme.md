## PhpTools.nvim

Neovim PhpTools - one step toward phpstorm
\*\*

https://github.com/ccaglak/phptools.nvim/assets/98365888/b1334c0a-2fc7-4fee-a60e-38bc39252107

## Info

-- thinking about rewriting the plugin.
-- if you have feature request or want to contribute please do. thanks

## Basic Usage

- `:PhpMethod` ex: $router->resolve(); Router::resolve(); (new Router)->resolve();  || generates undefined method and if generates class doesn't exist
- `:PhpClass` ex: new Router(); or class Router extends|implements Route || generates the undefined class, trait, interface, enums with with proper namespace also creates use statement for the current file
- `:PhpScripts` runs composer scripts
- `:PhpNamespace` generates namespace for the file
- `:PhpGetSet` -- public array $routes =[]; generates getter setter or both on cursor
- `:PhpRefactor` -- inline selected text to function/method -- more will be added
- `:PhpCreate` -- Create Class, Interface, Enum, or Trait in current file with namespace

## Install -- no default keymaps

```lua

{  -- lazy
    'ccaglak/phptools.nvim',
    keys = {
        { "<leader>lm", "<cmd>PhpMethod<cr>"},
        { "<leader>lc", "<cmd>PhpClass<cr>"},
        { "<leader>ls", "<cmd>PhpScripts<cr>"},
        { "<leader>ln", "<cmd>PhpNamespace<cr>"},
        { "<leader>lg", "<cmd>PhpGetSet<cr>"},
        { "<leader>lf", "<cmd>PhpCreate<cr>"},
    },
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    config = function()
      require('phptools').setup({
        ui = false, -- if you have stevearc/dressing.nvim or something similar keep it false or else true
      })
      vim.keymap.set('v','<leader>lr',':PhpRefactor<cr>')
    end
}

```

## Requires

- pleanery.nvim
- nvim-treesitter (`:TSInstall php json`)
- recommended stevearc/dressing.nvim but optional (read config)

## Features to be added

- custom templates
- append to codeactions
- ability make method public/protected/private
- custom template per directory base :? in Controller directory, controller template is generated
- run tests (run all, filter, file, line)

## Known bugs

- Let me know if you have any edge cases

## Check Out

- Laravel Goto Blade/Components [larago.nvim](https://github.com/ccaglak/larago.nvim).
- PHP Namespace Resolver [namespace.nvim](https://github.com/ccaglak/namespace.nvim).

## Inspired

- by PHPStorm

## License MIT
