local M = {}

local function is_laravel()
  return vim.fn.filereadable("artisan") == 1
end

local function execute_artisan(command, callback)
  vim.system({
    "php",
    "artisan",
    unpack(vim.split(command, " ")),
  }, {
    text = true,
    cwd = vim.fn.getcwd(),
  }, function(obj)
    if obj.code == 0 then
      vim.schedule(function()
        vim.notify(obj.stdout, vim.log.levels.INFO)
        if callback then
          callback(true)
        end
      end)
    else
      vim.schedule(function()
        vim.notify(obj.stderr, vim.log.levels.ERROR)
        if callback then
          callback(false)
        end
      end)
    end
  end)
end

function M.generate_model()
  if not is_laravel() then
    return
  end
  local model = vim.fn.expand("%:t:r")
  execute_artisan("ide-helper:models -N " .. model, function(success)
    if success then
      vim.notify("Generated helper for " .. model)
    end
  end)
end

-- Model selector and generator
function M.select_model()
  if not is_laravel() then
    return
  end

  local models = {}
  local handle = io.popen("ls app/Models/*.php") or error("Failed")
  for model in handle:lines() do
    table.insert(models, vim.fn.fnamemodify(model, ":t:r"))
  end
  handle:close()

  vim.ui.select(models, {
    prompt = "Select model:",
  }, function(choice)
    if choice then
      execute_artisan("ide-helper:models -N " .. choice)
    end
  end)
end

-- Generate all helpers
function M.generate_all()
  if not is_laravel() then
    print("woe")
    return
  end

  local commands = {
    "ide-helper:models -N",
    "ide-helper:generate",
    "ide-helper:meta",
  }

  local function run_next(index)
    if index > #commands then
      vim.notify("All helpers generated")
      return
    end
    execute_artisan(commands[index], function(success)
      if success then
        run_next(index + 1)
      end
    end)
  end

  run_next(1)
end

-- Individual generators
function M.generate_models()
  if not is_laravel() then
    return
  end
  execute_artisan("ide-helper:models -N")
end

function M.generate_meta()
  if not is_laravel() then
    return
  end
  execute_artisan("ide-helper:meta")
end

function M.generate_facades()
  if not is_laravel() then
    return
  end
  execute_artisan("ide-helper:generate")
end

-- Package installer
-- Replace the install function with this version
function M.install()
  if not is_laravel() then
    return
  end
  print("Installing IDE Helper...")
  vim.system({
    "composer",
    "require",
    "--dev",
    "barryvdh/laravel-ide-helper",
  }, {
    text = true,
  }, function(obj)
    if obj.code == 0 then
      -- Use vim.schedule to safely call vim.notify
      vim.schedule(function()
        vim.notify("IDE Helper installed")
        M.generate_all()
      end)
    end
  end)
end

-- Setup with keymaps and autocommands
function M.setup()
  local maps = {
    { "<Leader>lhg", M.generate_all, "Generate all helpers" },
    { "<Leader>lhm", M.generate_models, "Generate model helpers" },
    { "<Leader>lhf", M.generate_facades, "Generate facade helpers" },
    { "<Leader>lht", M.generate_meta, "Generate meta" },
    { "<Leader>lhs", M.select_model, "select model" },
    { "<Leader>lhi", M.install, "Install" },
  }

  for _, map in ipairs(maps) do
    vim.keymap.set("n", map[1], map[2], { desc = map[3] })
  end

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "app/Models/*.php",
    callback = M.generate_model,
  })
end

return M
