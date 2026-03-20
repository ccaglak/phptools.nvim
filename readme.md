## PhpTools.nvim v3.0.0

Elevate your PHP development in Neovim with PhpTools - bringing you one step closer to PHPStorm-like functionality ;).

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
- Laravel IDE Helper - automatically generates ide helpers
- **Smart `gf`** - Context-aware goto file for PHP, Blade, and Twig
- **Property Hooks** - Generate PHP 8.4 property hooks with validation
- Laravel, Symfony, Twig compatible

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

Command: `:PhpTools Scripts`

Runs Composer scripts defined in your `composer.json` file.

### PhpNamespace

Command: `:PhpTools Namespace`

Generates the appropriate namespace for the current file based on its location in the project structure.

### PhpGetSet

Command: `:PhpTools GetSet`

When the cursor is on a property declaration (e.g., `public array $routes = [];`), it generates getter, setter, or both for that property.


### PhpCreate

Command: `:PhpTools Create`

Create new PHP entities with intelligent Laravel project detection. The plugin automatically suggests the most appropriate template based on your project type and file location.

#### Basic Entities

Works with any PHP project:
- Class
- Interface
- Enum
- Trait
- Abstract class
- Pure PHP script (ps)
- Pure PHP script with autoloader (psa)

#### Laravel Smart Templates

When creating files in a Laravel project, the plugin detects your location and suggests contextual templates:

**Controllers** - Created in `app/Http/Controllers/` or filename contains `Controller`
```php
class UserController extends BaseController {
    public function index() { }
}
```

**Models** - Created in `app/Models/` or filename contains `Model`
```php
class User extends Model {
    protected $fillable = [];
}
```

**Form Requests** - Created in `app/Http/Requests/` or filename contains `Request`
```php
class StoreUserRequest extends FormRequest {
    public function authorize(): bool { }
    public function rules(): array { }
}
```

**Jobs** - Created in `app/Jobs/` or filename contains `Job`
```php
class ProcessJob implements ShouldQueue {
    public function handle(): void { }
}
```

**Events** - Created in `app/Events/` or filename contains `Event`
```php
class UserEvent implements ShouldBroadcast {
    // Broadcasting traits included
}
```

**Listeners** - Created in `app/Listeners/` or filename contains `Listener`
```php
class UserListener implements ShouldQueue {
    public function handle($event): void { }
}
```

**Seeders** - Created in `database/seeders/` or filename contains `Seeder`
```php
class UserSeeder extends Seeder {
    public function run(): void { }
}
```

**Migrations** - Created in `database/migrations/`
```php
return new class extends Migration {
    public function up(): void { }
    public function down(): void { }
};
```

#### How It Works

1. Open a new file in your Laravel project directory
2. Run `:PhpTools Create`
3. Plugin detects the directory and suggests the appropriate template first
4. Select from the list or choose a different template if needed
5. Template is generated with proper namespace and imports

### PhpPropertyHooks

Command: `:PhpTools PropertyHooks`

Generate PHP 8.4 property hooks with support for simple, validated, virtual, and lazy-loaded properties.

#### Quick Start

**On an existing property:**
```php
public string $email;  // Place cursor here
```
Run `:PhpTools PropertyHooks` → Select generation mode → Select hook type → Done!

**On an empty line:**
Run `:PhpTools PropertyHooks` → Enter property name → Enter type hint → Select hook type → Done!

#### Hook Types

**1. Simple Hooks** - Basic get/set with optional visibility control
```php
public string $email {
    get => $this->email;
    set(string $value) => $this->email = $value;
}
```

With visibility modifiers:
```php
public string $email {
    get => $this->email;
    private set(string $value) => $this->email = $value;
}
```

**2. Validated Hooks** - With built-in or custom validation
```php
public string $email {
    get => $this->email;
    set(string $value) {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) throw new \InvalidArgumentException('Invalid email');
        $this->email = $value;
    }
}
```

**3. Virtual Hooks** - Computed properties without backing field
```php
public string $fullName {
    get => $this->first . ' ' . $this->last;
}
```

**4. Lazy Hooks** - Lazy initialization with `??=` operator
```php
public Repository $repo {
    get => $this->repo ??= new Repository();
}
```

#### Validation Templates

Built-in templates include:
- String Length
- Positive Number
- Range
- Email
- URL
- Non-null
- Custom

#### Custom Templates

Add custom validation templates in your setup:

```lua
require('phptools').setup({
  property_hooks = {
    enable = true,
    custom_templates = {
      ["Min Length"] = "if (strlen($value) < 3) throw new \\InvalidArgumentException('Minimum 3 characters');",
      ["Alphanumeric"] = "if (!ctype_alnum($value)) throw new \\InvalidArgumentException('Alphanumeric only');",
      ["UUID"] = "if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $value)) throw new \\InvalidArgumentException('Invalid UUID');",
    },
  },
})
```

#### Workflow

**Step 1:** Generation Mode
- Single Property (one at a time)
- Batch (multiple properties)

**Step 2:** Hook Type
- Simple (basic get/set)
- Validated (with validation logic)
- Virtual (computed property)
- Lazy (lazy initialization)

### Smart GF

Press `gf` to navigate to the file under cursor. The plugin overrides Vim's native `gf` with context-aware navigation that understands PHP, Laravel, Symfony, and Twig. Falls back to default `gf` when no match is found.

#### PHP

| Context | Example | Navigates to |
|---------|---------|-------------|
| Constants | `require CONST_PATH . '/file.php'` | Resolved constant path |
| Environment | `require env('APP_PATH') . '/file.php'` | `.env` variable value |
| `__DIR__` | `require __DIR__ . '/config.php'` | Relative to current file |
| Array access | `require $files[0]` | Resolved array element |
| Class constants | `require Config::BASE_PATH . '/file'` | Resolved class constant |
| Routes | `route('users.index')`, `Route::get(...)` | Controller method |
| Migrations | `Schema::create('users', ...)` | Migration file |
| Middleware | `->middleware('auth')` | Middleware class |
| Locales | `__('messages.welcome')` | Locale file |
| Assets | `asset('css/app.css')`, `src="..."` | Asset file |
| Functions | `helper_function()` | Function definition |
| Inertia | `inertia('Pages/Dashboard')`, `Inertia::render(...)` | JS/Vue/React component |
| Services | `@service_name` (Symfony) | Service class |
| Entities | `getRepository('User')` (Symfony) | Entity class |
| Config | `config('app.name')` | Config file |

#### Blade

| Context | Example | Navigates to |
|---------|---------|-------------|
| Views | `view('admin.users.index')` | `resources/views/admin/users/index.blade.php` |
| Includes | `@include('partials.header')` | Blade partial |
| Extends | `@extends('layouts.app')` | Parent layout |
| Components | `@component('alert')` | Component file |
| Sections | `@section('content')` | Section definition |
| Livewire | `@livewire('user-profile')` | `app/Livewire/UserProfile.php` |
| Component tags | `<x-button>`, `<livewire:modal>` | Component file |
| Expressions | `{{ view('...') }}`, `{{ config('...') }}` | Resolved file |
| Livewire toggle | Cursor in `app/Livewire/` or `resources/views/livewire/` | Toggles between PHP class and Blade view |

#### Twig

| Context | Example | Navigates to |
|---------|---------|-------------|
| Include | `{% include 'partials/header.html.twig' %}` | Template file |
| Extends | `{% extends 'base.html.twig' %}` | Parent template |
| From/Import | `{% from 'macros.twig' import ... %}` | Template file |
| Embed | `{% embed 'block.twig' %}` | Template file |
| Controllers | `controller('App\\Controller\\Blog::index')` | Controller class |

#### Keymaps

| Keymap | Action |
|--------|--------|
| `gf` | Smart goto file (auto-detects context) |
| `<leader>gC` | Browse all Blade components |
| `<leader>gw` | Browse Livewire components |
| `<leader>gW` | Toggle Livewire component/view |
| `<leader>gr` | Browse Laravel routes |
| `<leader>gl` | Browse log files |
| `<leader>gL` | Tail Laravel logs |

All keymaps are configurable (set `false` to disable):

```lua
gf = {
  enable = true,
  keymaps = {
    gf = "gf",
    browse_components = "<leader>gC",
    browse_livewire = "<leader>gw",
    toggle_livewire = "<leader>gW",
    browse_routes = "<leader>gr",
    browse_logs = "<leader>gl",
    tail_logs = "<leader>gL",
  },
}
```

#### Tree-sitter-blade (optional)

For more accurate Blade directive parsing:
```vim
:TSInstall blade
```
Falls back to regex patterns if unavailable.

### PhpToggle

PhpTools.nvim includes a powerful toggle feature that enhances your PHP development workflow. This feature allows you to quickly switch between related keywords, operators, and values with simple key presses.

#### Features:

1. **Word Toggling**: Easily cycle through related PHP keywords and types.
   - Defaults:
     - `public` <-> `protected` <-> `private`
     - `self` <-> `static`
     - `true` <-> `false`
     - `require` <-> `include`
     - `abstract` <-> `final`
     - `class` <-> `interface` <-> `trait` <-> `enum`
     - `string` <-> `int` <-> `float` <-> `bool` <-> `array`

2. **Operator Toggling**: Quickly switch between related operators.
   - Default:
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
2. Execute the `:PhpTools Refactor` command
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

#### Features

- Automatically scans contributed modules directory
- Updates PSR-4 autoload configurations
- Watches for changes in composer.json and autoload files

### Laravel IDE Helper Integration

PhpTools.nvim includes built-in support for Laravel IDE Helper.

### Features

- Generate helpers for facades, models, and meta files
- One-command installation and setup
- Progress notifications for long-running operations



## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'ccaglak/phptools.nvim',
    keys = {
        { "<leader>lm", "<cmd>PhpTools Method<cr>", desc = "Generate method" },
        { "<leader>lc", "<cmd>PhpTools Class<cr>", desc = "Generate class" },
        { "<leader>ls", "<cmd>PhpTools Scripts<cr>", desc = "Run Composer scripts" },
        { "<leader>ln", "<cmd>PhpTools Namespace<cr>", desc = "Generate namespace" },
        { "<leader>lg", "<cmd>PhpTools GetSet<cr>", desc = "Generate getter/setter" },
        { "<leader>lp", "<cmd>PhpTools PropertyHooks<cr>", desc = "Generate property hooks" },
        { "<leader>lf", "<cmd>PhpTools Create<cr>", desc = "Create PHP entity" },
        { mode = "v", "<leader>lr", "<cmd>PhpTools Refactor<cr>", desc = "Refactor selection" },
    },
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require('phptools').setup({
        ui = {
          enable = true, -- custom UI for selects and input
          fzf = false,   -- use fzf for tests if available
        },
        custom_toggles = {
          enable = false, -- enable custom word/operator toggles
        },
        gf = {
          enable = true, -- smart gf navigation
          keymaps = {    -- set false to disable any keymap
            gf = "gf",
            browse_components = "<leader>gC",
            browse_livewire = "<leader>gw",
            toggle_livewire = "<leader>gW",
            browse_routes = "<leader>gr",
            browse_logs = "<leader>gl",
            tail_logs = "<leader>gL",
          },
        },
        larago = {
          enable = true, -- Laravel Blade navigation
        },
        property_hooks = {
          enable = true, -- PHP 8.4 property hooks
          custom_templates = {
            -- Add your custom validation templates here
            -- ["Template Name"] = "validation code",
          },
        },
      })

      local map = vim.keymap.set
      local ide_helper = require('phptools.ide_helper')
      local tests = require("phptools.tests")

      -- Laravel IDE Helper commands
      map('n', '<leader>lha', ide_helper.generate_all, { desc = 'Generate all IDE helpers' })
      map('n', '<leader>lhm', ide_helper.generate_models, { desc = 'Generate model helpers' })
      map('n', '<leader>lhf', ide_helper.generate_facades, { desc = 'Generate facade helpers' })

      -- Test runner commands
      map("n", "<Leader>ta", tests.test.all, { desc = "Run all tests" })
      map("n", "<Leader>tf", tests.test.file, { desc = "Run file tests" })
      map("n", "<Leader>tl", tests.test.line, { desc = "Run test at cursor" })
      map("n", "<Leader>ts", tests.test.filter, { desc = "Search tests" })
    end
}
```

### Using vim.pack (Native)

1. Clone the repository into your pack directory:

```bash
mkdir -p ~/.config/nvim/pack/plugins/start
cd ~/.config/nvim/pack/plugins/start
git clone https://github.com/ccaglak/phptools.nvim.git
```

2. Add configuration to your `init.lua`:

```lua
-- ~/.config/nvim/init.lua
require('phptools').setup({
  ui = {
    enable = true,      -- custom UI for selects and input
    fzf = false,        -- use fzf for tests if available
  },
  custom_toggles = {
    enable = false,     -- enable custom word/operator toggles
  },
  gf = {
    enable = true,      -- smart gf navigation
    keymaps = {         -- set false to disable any keymap
      gf = "gf",
      browse_components = "<leader>gC",
      browse_livewire = "<leader>gw",
      toggle_livewire = "<leader>gW",
      browse_routes = "<leader>gr",
      browse_logs = "<leader>gl",
      tail_logs = "<leader>gL",
    },
  },
  larago = {
    enable = true,      -- Laravel Blade navigation
  },
  property_hooks = {
    enable = true,      -- PHP 8.4 property hooks
    custom_templates = {
      -- Add your custom validation templates here
      -- ["Template Name"] = "validation code",
    },
  },
})

local map = vim.keymap.set

-- PhpTools code generation
map('n', '<leader>lm', '<cmd>PhpTools Method<cr>', { desc = 'Generate method' })
map('n', '<leader>lc', '<cmd>PhpTools Class<cr>', { desc = 'Generate class' })
map('n', '<leader>lg', '<cmd>PhpTools GetSet<cr>', { desc = 'Generate getter/setter' })
map('n', '<leader>lp', '<cmd>PhpTools PropertyHooks<cr>', { desc = 'Generate property hooks' })
map('n', '<leader>lf', '<cmd>PhpTools Create<cr>', { desc = 'Create PHP entity' })

-- PHP utilities
map('n', '<leader>ls', '<cmd>PhpTools Scripts<cr>', { desc = 'Run Composer scripts' })
map('n', '<leader>ln', '<cmd>PhpTools Namespace<cr>', { desc = 'Generate namespace' })
map('v', '<leader>lr', '<cmd>PhpTools Refactor<cr>', { desc = 'Refactor selection' })

-- IDE Helper commands
local ide_helper = require('phptools.ide_helper')
map('n', '<leader>lha', ide_helper.generate_all, { desc = 'Generate all IDE helpers' })
map('n', '<leader>lhm', ide_helper.generate_models, { desc = 'Generate model helpers' })
map('n', '<leader>lhf', ide_helper.generate_facades, { desc = 'Generate facade helpers' })
map('n', '<leader>lht', ide_helper.generate_meta, { desc = 'Generate meta helper' })
map('n', '<leader>lhi', ide_helper.install, { desc = 'Install IDE Helper package' })

-- Test runner commands
local tests = require("phptools.tests")
map('n', '<Leader>ta', tests.test.all, { desc = 'Run all tests' })
map('n', '<Leader>tf', tests.test.file, { desc = 'Run file tests' })
map('n', '<Leader>tl', tests.test.line, { desc = 'Run test at cursor' })
map('n', '<Leader>ts', tests.test.filter, { desc = 'Search and run test' })
map('n', '<Leader>tp', tests.test.parallel, { desc = 'Run tests in parallel' })
map('n', '<Leader>tr', tests.test.rerun, { desc = 'Rerun last test' })
map('n', '<Leader>ti', tests.test.selected, { desc = 'Run selected test file' })
```

## Requires
- Neovim >= 0.12
- ripgrep
- nvim-treesitter (`:TSInstall php json blade`)

## Features to be added
  - running out of ideas for now
  - your welcome to contribute or suggest features

## Known bugs
## Check Out

- PHP Namespace Resolver [namespace.nvim](https://github.com/ccaglak/namespace.nvim)
- Snippets.nvim [snippets.nvim](https://github.com/ccaglak/snippets.nvim)

## Inspired

- by PHPStorm

## Self Promotion

- Condo Painters Pro [Condo Painters Pro](https://www.condopainterspro.ca)

## License MIT
