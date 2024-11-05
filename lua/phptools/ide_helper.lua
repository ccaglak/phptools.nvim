local M = {}
local notify = require("phptools.notify").notify

local config = {
  models_path = "app/Models",
  artisan_path = "artisan",
  notify_timeout = 5000,
  composer_dev = true
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

local function is_laravel()
  return vim.fn.filereadable("artisan") == 1
end

local function execute_command(cmd, callback, silent)
  vim.system(cmd, {
    text = true,
    cwd = vim.fn.getcwd(),
  }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        if not silent then
          notify(obj.stdout, vim.log.levels.INFO)
        end
        callback(true, obj.stdout)
      else
        notify(obj.stderr, vim.log.levels.ERROR)
        callback(false, obj.stderr)
      end
    end)
  end)
end

local function execute_artisan(command, callback)
  local cmd = {
    "php",
    "artisan",
    unpack(vim.split(command, " ")),
  }
  execute_command(cmd, callback or function() end)
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
  if not is_laravel() then return end

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

function M.generate_models()
  if not is_laravel() then return end
  execute_artisan("ide-helper:models -N")
end

function M.generate_meta()
  if not is_laravel() then return end
  execute_artisan("ide-helper:meta")
end

function M.generate_facades()
  if not is_laravel() then return end
  execute_artisan("ide-helper:generate")
end

function M.install()
  if not is_laravel() then return end
  notify("Installing IDE Helper...")
  execute_command({
    "composer",
    "require",
    config.composer_dev and "--dev" or nil,
    "barryvdh/laravel-ide-helper",
  }, function(success)
    if success then
      notify("Installing IDE Helper completed", vim.log.levels.INFO)
      M.generate_facades()
      M.generate_models()
    end
  end, true)
end

return M
