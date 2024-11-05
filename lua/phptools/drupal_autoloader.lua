local uv = vim.uv

local M = {}

local cache = {
  project_root = nil,
  module_namespaces = {},
}

local notify = require('phptools.notify').notify

local sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"

local function normalize_path(path)
  path = path:gsub("[/\\]", sep)
  path = path:gsub(sep .. sep, sep)
  path = path:gsub(sep .. "$", "")
  return path
end

local function get_project_root()
  if cache.project_root then
    return cache.project_root
  end
  cache.project_root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
  return cache.project_root
end

local function scan_modules(modules_path)
  local modules = {}
  local handle = uv.fs_scandir(modules_path)

  while handle do
    local name, type = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == "directory" then
      local info_file = normalize_path(string.format("%s/%s/%s.info.yml", modules_path, name, name))
      if uv.fs_stat(info_file) then
        table.insert(modules, {
          name = name,
          path = modules_path .. sep .. name,
        })
      end
    end
  end

  return modules
end

local function get_module_namespace(module_path)
  local src_path = module_path .. sep .. "src"
  local handle = uv.fs_scandir(src_path)

  while handle do
    local name, type = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == "file" and name:match("%.php$") then
      local file_path = src_path .. sep .. name
      local content = vim.fn.join(vim.fn.readfile(file_path), "\n")

      local namespace = content:match("namespace%s+([^;]+)")
      if namespace then
        return namespace
      end
    end
  end

  local composer_file = module_path .. sep .. "composer.json"
  composer_file = composer_file:gsub("//", "/")
  local stat = uv.fs_stat(composer_file)

  if stat then
    local content = vim.fn.join(vim.fn.readfile(composer_file), "\n")
    local composer_data = vim.json.decode(content)
    if composer_data then
      return composer_data.name:gsub("/", "\\\\") .. "\\\\"
    end
  end

  return nil
end

local function build_autoload_map(modules)
  local map = {}
  for _, module in ipairs(modules) do
    local namespace = get_module_namespace(module.path)
    module.path = module.path:gsub(get_project_root(), "")
    if namespace then
      map[namespace] = { module.path .. sep .. "src" }
    end
  end
  return map
end

local function write_autoload_file(autoload_file, new_map)
  if not vim.loop.fs_stat(autoload_file) then
    notify(
      string.format("Autoload file not found: %s\nPlease run composer install first.", autoload_file),
      vim.log.levels.WARN
    )
    return
  end

  local content = vim.fn.join(vim.fn.readfile(autoload_file), "\n")

  for namespace, paths in pairs(new_map) do
    local formatted_namespace = namespace:gsub("\\", "\\\\") .. "\\\\"
    if not content:find(vim.pesc(formatted_namespace)) then
      local insert_pos = content:find("%);%s*$")
      if insert_pos then
        local new_entry = string.format("    '%s' => array($baseDir . '%s'),\n", formatted_namespace, paths[1])
        content = content:sub(1, insert_pos - 1) .. new_entry .. content:sub(insert_pos)

        local fd = uv.fs_open(autoload_file, "w", 438)
        if fd then
          uv.fs_write(fd, content)
          uv.fs_close(fd)
        end
      end
    end
  end
end

local function get_state_file()
  local state_dir = vim.fn.stdpath("state")
  return normalize_path(state_dir .. "/namespace_autoload.json")
end

local function read_state()
  local state_file = get_state_file()
  local stat = uv.fs_stat(state_file)
  if not stat then
    return nil
  end

  local fd = uv.fs_open(state_file, "r", 438)
  if not fd then
    return nil
  end

  local content = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)

  return vim.json.decode(content)
end

local function write_state(state)
  local state_file = get_state_file()
  local fd = uv.fs_open(state_file, "w", 438)
  if fd then
    uv.fs_write(fd, vim.json.encode(state))
    uv.fs_close(fd)
  end
end

local function is_files_modified()
  local drupal_root = get_project_root()
  local autoload_file = drupal_root .. normalize_path(M.config.autoload_file)
  local composer_file = drupal_root .. "/composer.json"

  local autoload_stat = uv.fs_stat(autoload_file)
  local composer_stat = uv.fs_stat(composer_file)

  local state = read_state() or {}
  local last_autoload_modified = state.last_autoload_modified or 0
  local last_composer_modified = state.last_composer_modified or 0

  local is_modified = false
  if autoload_stat.mtime.sec > last_autoload_modified or composer_stat.mtime.sec > last_composer_modified then
    write_state({
      last_autoload_modified = autoload_stat.mtime.sec,
      last_composer_modified = composer_stat.mtime.sec,
    })
    is_modified = true
  end

  return is_modified
end

M.config = {
  scan_paths = { "/web/modules/contrib/" },
  root_markers = { ".git" },
  autoload_file = "/vendor/composer/autoload_psr4.php",
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = { "autoload_psr4.php", "composer.json" },
    callback = function()
      local file = vim.fn.expand("%:t")
      if file == "composer.json" then
        M.update_autoload()
      elseif file == "autoload_psr4.php" and is_files_modified() then
        M.update_autoload()
      end
    end,
  })
end

function M.update_autoload()
  local drupal_root = get_project_root()
  for _, scan_path in ipairs(M.config.scan_paths) do
    local modules_path = drupal_root .. normalize_path(scan_path)
    local autoload_file = drupal_root .. normalize_path(M.config.autoload_file)

    local autoload_map = build_autoload_map(scan_modules(modules_path))
    vim.schedule(function()
      write_autoload_file(autoload_file, autoload_map)
    end)
  end
end

return M
