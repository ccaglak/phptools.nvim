# PhpTools Setup Diagnostic

If the GetSet window never opens (not even a flicker), the most likely cause is that **setup() was not called**.

## How to Check

### Step 1: Verify Setup is Called

Add this to your Neovim config:

```lua
-- In init.lua or init.vim
require('phptools').setup({
  ui = { enable = true, fzf = false },
})
```

**Without this line, the UI will NOT work.**

### Step 2: Check If Setup Was Called

In Neovim, run:
```vim
:lua print(vim.ui.select)
```

You should see something like: `function: 0x...`

**Before setup():**
- Shows the **builtin** Neovim select

**After setup():**
- Shows the **phptools custom** select function

### Step 3: Verify in GetSet

When you run `:PhpTools GetSet`, check `:messages`:

**If you see:**
```
Warning: vim.ui.select not overridden. Did you call require('phptools').setup()?
```

→ **You forgot to call setup()**

**If you see:**
```
Failed to open UI window: ...
```

→ **There's a window creation error** (check the error message for details)

**If you see nothing:**
→ **Window should be open** - check if it's off-screen or partially visible

## Full Setup Example

### Lazy.nvim
```lua
{
  'ccaglak/phptools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter' },
  config = function()
    require('phptools').setup({
      ui = { enable = true, fzf = false },
      php_gf = { enable = true },
      larago = { enable = true },
    })
  end,
}
```

### Manual Installation
```lua
-- In your init.lua
require('phptools').setup({
  ui = { enable = true, fzf = false },
  php_gf = { enable = true },
  larago = { enable = true },
})

-- Optional: Set keymaps
vim.keymap.set('n', '<leader>lg', '<cmd>PhpTools GetSet<cr>', { noremap = true })
```

### Neovim Config (vim.lua)
```lua
-- Setup phptools
require('phptools').setup({
  ui = { enable = true },
})

-- Map leader-lg to getset
local keymap = vim.keymap.set
keymap('n', '<leader>lg', '<cmd>PhpTools GetSet<cr>', { noremap = true, silent = true })
```

## Troubleshooting

### The Window Still Never Opens

After ensuring setup() is called, check:

1. **Position cursor correctly:**
   ```php
   public string $name;  // ← Cursor here
   ```

2. **Run command:**
   ```vim
   :PhpTools GetSet
   ```
   Or with keymap:
   ```vim
   <leader>lg
   ```

3. **Check messages:**
   ```vim
   :messages
   ```

Look for any of these messages:
- ✅ Window should open
- ⚠️ "No property found..." - cursor not on property
- ⚠️ "vim.ui.select not overridden..." - setup() not called
- ❌ "Failed to open UI window..." - window creation failed

### Window Opens But Is Invisible

- Try resizing window: `:set lines=30 columns=120`
- Try moving cursor away and back
- Check if window is off-screen (too large or negative position)

### Still Not Working?

Run this debug command:
```vim
:lua require('phptools.ui').norm_select(
  {'Get', 'Set', 'Get/Set'},
  {prompt = 'Test:'},
  function(choice) print('Selected: ' .. tostring(choice)) end
)
```

If the window appears here, the issue is with getset. If not, the issue is with UI setup.

## Key Points

| Issue | Solution |
|-------|----------|
| Window never opens | Call `require('phptools').setup()` |
| Window opens but invisible | Check terminal size/position |
| "No property found" message | Position cursor on property declaration |
| Builtin Neovim dialog appears | Setup() not called or ui.enable = false |
| Window flickers | **Already fixed** - bufhidden set to "hide" |

## Minimum Working Config

```lua
-- init.lua
require('phptools').setup()  -- Use defaults

-- Set keymap (optional)
vim.keymap.set('n', '<leader>lg', '<cmd>PhpTools GetSet<cr>')
```

That's it! Now `:PhpTools GetSet` should work.
