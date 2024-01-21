local M = {}

function M.run()
  M.select(M.art, {
    prompt = "Run Tasks",
  }, function(selection)
    if not selection then
      return
    end
    if not selection:find(":", 1, true) then
      vim.cmd.term("php artisan " .. selection)
      return
    end
    vim.ui.input({ prompt = selection, relative = "editor" }, function(name)
      if name == nil then
        return
      end
      vim.cmd.term("php artisan " .. selection .. " " .. name)
    end)
  end)
end

M.art = {
  "about",
  "clear-compiled",
  "completion",
  "db",
  "docs",
  "down",
  "env",
  "help",
  "inspire",
  "list",
  "migrate",
  "optimize",
  "serve",
  "test",
  "tinker",
  "up",
  -- auth
  "auth:clear-resets",
  -- "cache",
  "cache:clear",
  "cache:forget",
  "cache:prune-stale-tags",
  "cache:table",
  -- "channel",
  "channel:list",
  -- "config",
  "config:cache",
  "config:clear",
  "config:show",
  -- "db",
  "db:monitor",
  "db:seed",
  "db:show",
  "db:table",
  "db:wipe",
  -- "env",
  "env:decrypt",
  "env:encrypt",
  -- "event",
  "event:cache",
  "event:clear",
  "event:generate",
  "event:list",
  -- "key",
  "key:generate",
  -- "lang",
  "lang:publish",
  -- "make",
  "make:cast",
  "make:channel",
  "make:command",
  "make:component",
  "make:controller",
  "make:event",
  "make:exception",
  "make:factory",
  "make:job",
  "make:listener",
  "make:mail",
  "make:middleware",
  "make:migration",
  "make:model",
  "make:notification",
  "make:observer",
  "make:policy",
  "make:provider",
  "make:request",
  "make:resource",
  "make:rule",
  "make:scope",
  "make:seeder",
  "make:test",
  "make:view",
  -- "migrate",
  "migrate:fresh",
  "migrate:install",
  "migrate:refresh",
  "migrate:reset",
  "migrate:rollback",
  "migrate:status",
  -- "model",
  "model:prune",
  "model:show",
  -- "notifications",
  "notifications:table",
  -- "optimize",
  "optimize:clear",
  -- "package",
  "package:discover",
  -- "queue",
  "queue:batches-table",
  "queue:clear",
  "queue:failed",
  "queue:failed-table",
  "queue:flush",
  "queue:forget",
  "queue:listen",
  "queue:monitor",
  "queue:prune-batches",
  "queue:prune-failed",
  "queue:restart",
  "queue:retry",
  "queue:retry-batch",
  "queue:table",
  "queue:work",
  -- "route",
  "route:cache",
  "route:clear",
  "route:list",
  -- "sail",
  "sail:add",
  "sail:install",
  "sail:publish",
  -- "sanctum",
  "sanctum:prune-expired",
  -- "schedule",
  "schedule:clear-cache",
  "schedule:interrupt",
  "schedule:list",
  "schedule:run",
  "schedule:test",
  "schedule:work",
  -- "schem",
  "schema:dump",
  -- "session",
  "session:table",
  -- "storage",
  "storage:link",
  -- "stub",
  "stub:publish",
  -- "vendor",
  "vendor:publish",
  -- "view",
  "view:cache",
  "view:clear",
}

function M.select(items, opts, on_choice)
  local action_set = require("telescope.actions.set")
  local actions = require("telescope.actions")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local state = require("telescope.actions.state")

  opts = opts or {}
  on_choice = on_choice or function() end

  pickers
    .new({
      prompt_title = opts.prompt or "",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          local text = (opts.format_item or tostring)(item)
          return { display = text, ordinal = text, value = item }
        end,
      }),
      sorter = conf.generic_sorter(),
      layout_strategy = "horizontal",
      layout_config = {
        horizontal = { width = 60, height = 16 },
      },
      results_title = false,
      attach_mappings = function()
        action_set.select:replace(function(prompt_bufnr)
          actions.close(prompt_bufnr, false)
          local selected = state.get_selected_entry() or {}
          on_choice(selected.value, selected.index)
        end)

        return true
      end,
    })
    :find()
end

return M
