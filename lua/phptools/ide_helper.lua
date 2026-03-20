local M = {}

-- Default configuration
local config = {
  models_path = "app/Models",
  artisan_path = "artisan",
  notify_timeout = 5000,
  composer_dev = true,
}

-- IDE Helper generation commands
local HELPER_COMMANDS = {
  "ide-helper:models -N",
  "ide-helper:generate",
  "ide-helper:meta",
}

-- Artisan generate command names mapped to methods
local ARTISAN_GENERATORS = {
  models = "ide-helper:models -N",
  facades = "ide-helper:generate",
  meta = "ide-helper:meta",
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

local function is_laravel()
  return vim.fn.filereadable("artisan") == 1
end

local function require_laravel(fn_name)
  if not is_laravel() then
    vim.notify("Not a Laravel project (artisan file not found)", vim.log.levels.WARN)
    return false
  end
  return true
end

local function execute_command(cmd, callback, silent)
  vim.system(cmd, {
    text = true,
    cwd = vim.fn.getcwd(),
  }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        if not silent then
          vim.notify(obj.stdout, vim.log.levels.INFO)
        end
        callback(true, obj.stdout)
      else
        vim.notify(obj.stderr, vim.log.levels.ERROR)
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
  local notify_id = vim.notify(message .. "...", vim.log.levels.INFO, {
    title = "Laravel IDE Helper",
    timeout = false,
    replace = true,
  })

  fn(function()
    vim.notify(message .. " completed", vim.log.levels.INFO, {
      replace = notify_id,
    })
  end)
end

local function generate_helper(command_name, with_progress_msg)
  if not require_laravel("generate") then
    return
  end

  local command = ARTISAN_GENERATORS[command_name]
  if not command then
    vim.notify("Unknown generator: " .. command_name, vim.log.levels.ERROR)
    return
  end

  if with_progress_msg then
    with_progress(with_progress_msg, function(done)
      execute_artisan(command, function(success)
        if success then
          done()
        end
      end)
    end)
  else
    execute_artisan(command)
  end
end

function M.generate_all()
  if not require_laravel("generate_all") then
    return
  end

  local function run_next(index)
    if index > #HELPER_COMMANDS then
      vim.notify("All helpers generated", vim.log.levels.INFO)
      return
    end

    with_progress("Generating helper " .. index .. "/" .. #HELPER_COMMANDS, function(done)
      execute_artisan(HELPER_COMMANDS[index], function(success)
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
  generate_helper("models", "Generating models helper")
end

function M.generate_meta()
  generate_helper("meta", "Generating meta helper")
end

function M.generate_facades()
  generate_helper("facades", "Generating facades helper")
end

function M.install()
  if not require_laravel("install") then
    return
  end

  vim.notify("Installing IDE Helper...")

  local composer_cmd = {
    "composer",
    "require",
    "barryvdh/laravel-ide-helper",
  }

  if config.composer_dev then
    table.insert(composer_cmd, 3, "--dev")
  end

  execute_command(composer_cmd, function(success)
    if success then
      vim.notify("Installing IDE Helper completed", vim.log.levels.INFO)
      M.generate_facades()
      M.generate_models()
    end
  end, true)
end

return M
