local M = {}

-- does this have any value?

local notify = require("phptools.notify").notify

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
        notify(obj.stdout, vim.log.levels.INFO)
        if callback then
          callback(true)
        end
      end)
    else
      vim.schedule(function()
        notify(obj.stderr, vim.log.levels.ERROR)
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
      notify("Generated helper for " .. model)
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

local function with_progress(message, fn)
  local notify_id = notify(message .. "...", vim.log.levels.INFO, {
    title = "Laravel IDE Helper",
    timeout = false,
    replace = true,
  })

  fn(function()
    notify(message .. " completed", vim.log.levels.INFO, {
      replace = notify_id,
    })
  end)
end

function M.generate_all()
  if not is_laravel() then
    return
  end

  local commands = {
    "ide-helper:models -N",
    "ide-helper:generate",
    "ide-helper:meta",
  }

  local function run_next(index)
    if index > #commands then
      notify("All helpers generated", vim.log.levels.INFO)
      return
    end

    with_progress("Generating helper " .. index .. "/" .. #commands, function(done)
      execute_artisan(commands[index], function(success)
        if success then
          done()
          run_next(index + 1)
        end
      end)
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

function M.install()
  if not is_laravel() then
    return
  end
  notify("Installing IDE Helper...")
  vim.system({
    "composer",
    "require",
    "--dev",
    "barryvdh/laravel-ide-helper",
  }, {
    text = true,
  }, function(obj)
    if obj.code == 0 then
      vim.schedule(function()
        notify("IDE Helper installed")
        M.generate_facades()
        M.generate_models()
      end)
    end
  end)
end

return M
