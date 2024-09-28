## PhpTools.nvim

Elevate your PHP development in Neovim with PhpTools - bringing you one step closer to PHPStorm-like functionality.

![PhpTools Demo](https://github.com/ccaglak/phptools.nvim/assets/98365888/b1334c0a-2fc7-4fee-a60e-38bc39252107)

## Features

- Generate undefined methods and classes
- Create classes, traits, interfaces, and enums with proper namespacing
- Run Composer scripts
- Generate namespaces for files
- Create getters and setters
- Refactor inline code to functions/methods
- Create PHP entities (Class, Interface, Enum, Trait) with namespaces

## Detailed Usage

### PhpMethod

Command: `:PhpMethod`

Generates undefined methods. Works with:
- Object methods: `$router->resolve();`
- Static methods: `Router::resolve();`
- Instantiated methods: `(new Router)->resolve();`
- Enum declaration: `Router::findroot()`

If the class doesn't exist, it will also generate the class.

### PhpClass

Command: `:PhpClass`

Creates undefined classes, traits, interfaces, or enums. Supports:
- Class instantiation: `new Router();`
- Class declaration: `class Router extends|implements Route`
- Trait usage: `use TraitName;`
- Enum declaration: `Router::findroot()`

Generates the entity with proper namespace and creates a use statement for the current file.

### PhpScripts

Command: `:PhpScripts`

Runs Composer scripts defined in your `composer.json` file.

### PhpNamespace

Command: `:PhpNamespace`

Generates the appropriate namespace for the current file based on its location in the project structure.

### PhpGetSet

Command: `:PhpGetSet`

When the cursor is on a property declaration (e.g., `public array $routes = [];`), it generates getter, setter, or both for that property.

### PhpRefactor

Command: `:PhpRefactor`

Works on visually selected text. Options include:
- Inline selected text to a function
- Inline selected text to a method

More refactoring options will be added in future updates.

### PhpCreate

Command: `:PhpCreate`

Allows you to create a new PHP entity (Class, Interface, Enum, or Trait) in the current file, complete with the correct namespace.

To use these commands effectively, map them to convenient keybindings as shown in the installation section. This will allow quick access to PhpTools functionality while coding.

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
     - `array_map` <-> `array_filter` <-> `array_reduce`

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

#### Configuration:

You can add custom toggle groups by passing a configuration table to the setup function:

```lua
require('phptools.toggle').setup({
    custom_toggles = {
        { "foo", "bar", "baz" },
        -- Add more custom toggle groups here
    }
})

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):


{
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
        ui = false, -- Set to true if not using a UI enhancement plugin
      })
      vim.keymap.set('v','<leader>lr',':PhpRefactor<cr>')
    end
}


## Requires

- pleanery.nvim
- nvim-treesitter (`:TSInstall php json`)
- recommended stevearc/dressing.nvim but optional (read config)

## Features to be added

- custom templates
- append to codeactions
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
