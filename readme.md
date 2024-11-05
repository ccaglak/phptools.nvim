## PhpTools.nvim v2.0.0

Elevate your PHP development in Neovim with PhpTools - bringing you one step closer to PHPStorm-like functionality ;).

https://github.com/ccaglak/phptools.nvim/assets/98365888/b1334c0a-2fc7-4fee-a60e-38bc39252107

## Features

- Generate undefined methods
- Create classes, traits, interfaces, and enums with proper namespacing, including `use` statements
- Run Composer scripts
- Generate namespaces for files
- Create getters and setters
- Create PHP entities (Class, Interface, Enum, Trait) with namespaces
- Toggles common words <C-a> / <C-x> or fallbacks
- Refactor with common structures and control flow statements
- Run PHPUnit/Pest tests
- Drupal autoloader - automatically manages PSR-4 autoloading for Drupal modules
- Laravel IDE Helper - automatically generates ide helpers
- Laravel, Symfony, Drupal compatible

## Detailed Usage

### PhpMethod

Command: `:PhpTools Method`

Generates undefined methods under cursor. Works with:
- Object methods: `$router->resolve();`, `$this->container->get(Router::class);`, `$this->get()`
- Static methods: `Router::resolve();`
- Instantiated methods: `(new Router)->resolve();`
- Static : `Router::findroot()`
- Enum : `Color::RED`

If the class doesn't exist, it will also generate the class.

### PhpClass

Command: `:PhpTools Class`

Creates undefined classes, traits, interfaces, or enums under cursor. Supports:
- Class instantiation: `new Router();`
- Class declaration: `class Router extends|implements Route`
- Trait usage: `use TraitName;`
- Enum declaration: `Color::RED`
- Static declaration: `Router::findroot()`
- Simple Parameter: `function foo(Router $router) {}`

Generates the entity with proper namespace and creates a use statement for the current file.

### PhpScripts

Command: `:Php Scripts`

Runs Composer scripts defined in your `composer.json` file.

### PhpNamespace

Command: `:PhpTools Namespace`

Generates the appropriate namespace for the current file based on its location in the project structure.

### PhpGetSet

Command: `:PhpTools GetSet`

When the cursor is on a property declaration (e.g., `public array $routes = [];`), it generates getter, setter, or both for that property.


### PhpCreate

Command: `:PhpTools Create`

Allows you to create a new PHP entity (Class, Interface, Enum, or Trait) in the current file, complete with the correct namespace.

### PhpToggle

PhpTools.nvim includes a powerful toggle feature that enhances your PHP development workflow. This feature allows you to quickly switch between related keywords, operators, and values with simple key presses.

#### Features:

1. **Word Toggling**: Easily cycle through related PHP keywords and types.
   - Examples:
     - `public` <-> `protected` <-> `private`
     - `self` <-> `static`
     - `true` <-> `false`
     - `require` <-> `include`
     - `abstract` <-> `final`
     - `class` <-> `interface` <-> `trait` <-> `enum`
     - `string` <-> `int` <-> `float` <-> `bool` <-> `array`

2. **Operator Toggling**: Quickly switch between related operators.
   - Examples:
     - `==` <-> `===`
     - `!=` <-> `!==`
     - `>` <-> `>=`
     - `<` <-> `<=`
     - `&&` <-> `||`
     - `++` <-> `--`
     - `->` <-> `=>`

3. **Custom Toggles**: Add your own custom toggle groups to suit your specific needs.

#### Usage:

- In normal mode, place your cursor on a word or operator and press:
  - `<C-a>` to cycle forward through toggles
  - `<C-x>` to cycle backward through toggles

- If the word or operator under the cursor isn't part of a toggle group, it will increment or decrement numbers as usual.

### PhpRefactor

Command: `:PhpTools Refactor`

Quickly surround your PHP code with common structures and control flow statements.

### Usage:

1. Select the text you want to surround in visual/visualline mode
2. Execute the `:Php Refactor` command
3. Choose from the available options:

   - `if`: Wraps the selection in an if statement
   - `for`: Creates a for loop around the selection
   - `foreach`: Surrounds the selection with a foreach loop
   - `while`: Wraps the selection in a while loop
   - `do-while`: Puts the selection inside a do-while loop
   - `try-catch`: Encloses the selection in a try-catch block
   - `function`: Creates a function around the selection
   - `method`: Wraps the selection in a method

#### Example:

```php
// Before (with 'echo "Hello, World!";' selected)
echo "Hello, World!";

// After choosing 'if' from Php Refactor
if (condition) {
    echo "Hello, World!";
}
```

## PHP Testing Features

PhpTools.nvim provides comprehensive test running capabilities for PHP projects using PHPUnit or Pest.

### Features

- Automatically detects and uses PHPUnit or Pest test runner
- Supports multiple test patterns:
  - PHPUnit method annotations (`@test`)
  - Test method prefixes (`test_*`)
  - Pest test definitions (`test()`, `it()`)
- Interactive test output in a floating window
  - Press `q` or `Esc` to close
  - Use `gf` to jump to failed test file
- Smart test detection:
  - Finds nearest test based on cursor position
  - Supports both class-based and function-based tests

### Test Runner Features

- Run all tests in project
- Run single test file
- Filter and run specific tests
- Parallel test execution support
- Re-run last test



https://github.com/user-attachments/assets/61828e80-f165-4cc0-bc90-414d5401eacc



## Drupal Autoloader

PhpTools.nvim includes a powerful Drupal autoloader that automatically manages PSR-4 autoloading for Drupal modules. This feature helps keep your autoload configurations up-to-date as you develop Drupal modules.

#### Features

- Automatically scans contributed modules directory
- Updates PSR-4 autoload configurations
- Watches for changes in composer.json and autoload files
- Maintains proper namespacing for Drupal modules

### Toggle
### Function Style Toggling
- Switch between arrow functions and traditional PHP functions
- Seamlessly convert between fn() => expression and function() { return expression; }
- Toggle quotes
## Conditional Statement Transformations
- Toggle between if-else statements and ternary operators
- Convert between traditional if-else blocks and match expressions

https://github.com/user-attachments/assets/3d923edf-bf31-4c9d-aeca-b73557380bc1


### Laravel IDE Helper Integration

PhpTools.nvim includes built-in support for Laravel IDE Helper.

### Features

- Generate helpers for facades, models, and meta files
- Interactive model selection for targeted generation
- One-command installation and setup
- Progress notifications for long-running operations

### Automatic Features

- Auto-generates model helpers when saving files in `app/Models/`
- Shows progress notifications during helper generation
- Validates Laravel project structure before operations


## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'ccaglak/phptools.nvim',
    keys = {
        { "<leader>lm", "<cmd>PhpTools Method<cr>"},
        { "<leader>lc", "<cmd>PhpTools Class<cr>"},
        { "<leader>ls", "<cmd>PhpTools Scripts<cr>"},
        { "<leader>ln", "<cmd>PhpTools Namespace<cr>"},
        { "<leader>lg", "<cmd>PhpTools GetSet<cr>"},
        { "<leader>lf", "<cmd>PhpTools Create<cr>"},
        { "<leader>ld", "<cmd>PhpTools DrupalAutoLoader<cr>"},
        { mode="v", "<leader>lr", "<cmd>PhpTools Refactor<cr>"},
    },
    dependencies = {
         "ccaglak/namespace.nvim", -- optional - php namespace resolver
        "ccaglak/larago.nvim", -- optional -- laravel goto blade/components
        -- "ccaglak/snippets.nvim", -- optional -- native snippet expander
    },
    config = function()
      require('phptools').setup({
         ui = {
          enable = true, -- default:true; false only if you have a UI enhancement plugin
          fzf = false -- default:false; requires fzf used only in tests module otherwise there might long list  of tests
        },
        create = false, -- default:false autorun PhpTools Create when creating a new php file
        drupal_autoloader = { -- delete if you dont use it
          scan_paths = { "/web/modules/contrib/" }, -- Paths to scan for modules
          root_markers = { ".git" },                -- Project root markers
          autoload_file = "/vendor/composer/autoload_psr4.php" -- Autoload file path
        },
        custom_toggles = {
        -- { "foo", "bar", "baz" }, -- Add more custom toggle groups here
        }
      })

      local map = vim.keymap.set

      local ide_helper = require('phptools.ide_helper')
      -- Laravel IDE Helper keymaps
      map('n', '<leader>lha', ide_helper.generate_all, { desc = 'Generate all IDE helpers' })
      map('n', '<leader>lhm', ide_helper.generate_models, { desc = 'Generate model helpers' })
      map('n', '<leader>lhf', ide_helper.generate_facades, { desc = 'Generate facade helpers' })
      map('n', '<leader>lht', ide_helper.generate_meta, { desc = 'Generate meta helper' })
      map('n', '<leader>lhi', ide_helper.install, { desc = 'Install IDE Helper package' })


      local tests = require("phptools.tests")
      map("n", "<Leader>ta", tests.test.all, { desc = "Run all tests" })
      map("n", "<Leader>tf", tests.test.file, { desc = "Run current file tests" })
      map("n", "<Leader>tl", tests.test.line, { desc = "Run test at cursor" })
      map("n", "<Leader>ts", tests.test.filter, { desc = "Search and run test" })
      map("n", "<Leader>tp", tests.test.parallel, { desc = "Run tests in parallel" })
      map("n", "<Leader>tr", tests.test.rerun, { desc = "Rerun last test" })
      map("n", "<Leader>ti", tests.test.selected, { desc = "Run selected test file" })

      local fn = require('phptools.fn')
      map('n', '<leader>llf', fn.toggle_function, { desc = 'Toggle PHP function style' })
      map('n', '<leader>lli', fn.toggle_if_ternary, { desc = "Toggle if/ternary" })
      map('n', '<leader>llm', fn.toggle_if_match, { desc = "Toggle if/match" })
      map('n', '<leader>llm', fn.toggle_quotes, { desc = "Toggle qoutes" })

    end
}
```


## Requires
- ripgrep
- nvim-treesitter (`:TSInstall php json`)

## Features to be added
  -- running out of ideas for now
  -- your welcome to contribute or suggest features

## Known bugs
## Check Out

- PHP Namespace Resolver [namespace.nvim](https://github.com/ccaglak/namespace.nvim).
- Snippets.nvim [snippets.nvim](https://github.com/ccaglak/snippets.nvim).
- Laravel Goto Blade/Components [larago.nvim](https://github.com/ccaglak/larago.nvim).

## Inspired

- by PHPStorm

## License MIT
