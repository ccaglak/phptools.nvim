## PhpTools.nvim

Neovim PhpTools - one step toward phpstorm
**


https://github.com/ccaglak/phptools.nvim/assets/98365888/0ceb336d-c18c-470d-bd35-d7b703a04d29


## Basic Usage

-   `:PhpMethod` ex: $router->resolve(); || generates undefined method in class
-   `:PhpClass`  ex: new Router(); or class Router extends|implements Route || generates the undefined class, trait, interface, enums with with proper namespace also creates use statement for the current file
-   `:PhpScripts` runs composer scripts
-   `:PhpNamespace` generates namespace for the file
-   `:PhpGetSet` -- public array $routes =[]; generates getter setter or both on cursor
-   `:PhpRefactor` -- inline selected text to function/method  -- more will be added
-   `:PhpArtisan` -- Laravel artisan commands

## Install    -- no default keymaps

```lua

{  -- lazy
    'ccaglak/phptools.nvim',
    keys = {
        { "<leader>lm", "<cmd>PhpMethod<cr>"},
        { "<leader>lc", "<cmd>PhpClass<cr>"},
        { "<leader>ls", "<cmd>PhpScripts<cr>"},
        { "<leader>ln", "<cmd>PhpNamespace<cr>"},
        { "<leader>lg", "<cmd>PhpGetSet<cr>"},
        { "<leader>la", "<cmd>PhpArtisan<cr>"},
    },
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    config = function()
      require('phptools').setup({
        ui = false, -- default is false if you have stevearc/dressing.nvim or something similar keep it false
      })
      vim.keymap.set('v','<leader>lr',':PhpRefactor<cr>')
    end
}

```

## Requires

-   pleanery.nvim
-   nvim-treesitter (`:TSInstall php json`)
-   recommended

## Features to be added
- custom templates
- append to codeactions
- laravel artisan command center
- ability make method public/protected/private
- custom template per directory base :? in Controller directory, controller template is generated
- run tests (run all, filter, file, line)

## Known bugs
-   Let me know if you have any edge cases

## Check Out

- Laravel Goto Blade/Components [larago.nvim](https://github.com/ccaglak/larago.nvim).
- PHP Namespace Resolve [namespace.nvim](https://github.com/ccaglak/namespace.nvim).


## Inspired

-   by PHPStorm

## License MIT
