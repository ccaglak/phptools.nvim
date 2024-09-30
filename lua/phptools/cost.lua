local VERSION = "0.1.0"
local ComposerCost = {
  ns = vim.api.nvim_create_namespace("composer_cost"),
  packs = {},
  config = {
    cache_ttl = 3600, -- 1 hour
    highlight_groups = {
      up_to_date = "DiffAdd",
      outdated = "DiffDelete",
      error = "Error",
      fetching = "Comment",
    },
    check_dev_dependencies = true,
  },
}

local version_cache = {}
local composer_data_cache = { data = nil, timestamp = 0, mtime = 0 }

local function get_latest_version(package, callback)
  if version_cache[package] and os.time() - version_cache[package].timestamp < ComposerCost.config.cache_ttl then
    return callback(version_cache[package].data)
  end

  local cmd = string.format("composer show %s --latest --format=json", package)
  local output = ""
  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_exit = function()
      local ok, package_info = pcall(vim.json.decode, output)
      if ok and package_info.latest then
        version_cache[package] = { data = package_info, timestamp = os.time() }
        callback(package_info)
      else
        print("Failed to get latest version for " .. package)
        callback(nil)
      end
    end,
  })

  if job_id == 0 then
    callback(nil)
  elseif job_id == -1 then
    callback(nil)
  end
end

local function get_composer_data()
  local composer_file = "composer.json"
  local file_mtime = vim.fn.getftime(composer_file)

  if
    composer_data_cache.data
    and file_mtime == composer_data_cache.mtime
    and os.time() - composer_data_cache.timestamp < ComposerCost.config.cache_ttl
  then
    return composer_data_cache.data
  end

  local ok, content = pcall(vim.fn.readfile, composer_file)
  if not ok then
    print("Error reading composer.json")
    return nil
  end
  local composer_json = table.concat(content, "\n")
  local ok, decoded = pcall(vim.json.decode, composer_json)
  if ok then
    composer_data_cache = { data = decoded, timestamp = os.time(), mtime = file_mtime }
    return decoded
  else
    print("Error parsing composer.json")
    return nil
  end
end

local function update_extmark(package, line, text, hl_group)
  if not ComposerCost.packs[package] then
    ComposerCost.packs[package] = {
      id = vim.api.nvim_buf_set_extmark(0, ComposerCost.ns, line, 0, {
        virt_text = { { text, hl_group } },
        virt_text_pos = "eol",
      }),
    }
  else
    vim.api.nvim_buf_set_extmark(0, ComposerCost.ns, line, 0, {
      virt_text = { { text, hl_group } },
      id = ComposerCost.packs[package].id,
    })
  end
end

local function compare_versions(current, latest)
  local function parse_version(v)
    if not v then
      return { 0, 0, 0 }
    end
    local major, minor, patch = v:match("(%d+)%.(%d+)%.?(%d*)")
    return { tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0 }
  end
  local c_version = parse_version(current)
  local l_version = parse_version(latest)

  for i = 1, 3 do
    if c_version[i] < l_version[i] then
      return -1
    elseif c_version[i] > l_version[i] then
      return 1
    end
  end
  return 0
end

local function process_package(package, version, line)
  if package == "php" then
    return
  end

  update_extmark(package, line, "Fetching...", ComposerCost.config.highlight_groups.fetching)

  get_latest_version(package, function(data)
    vim.schedule(function()
      if data and data.latest then
        local latest_version = data.latest
        if version and latest_version then
          local comparison = compare_versions(version, latest_version)
          local display = string.format(" (%s -> %s)", version, latest_version)
          local hl_group = comparison < 0 and ComposerCost.config.highlight_groups.outdated
            or ComposerCost.config.highlight_groups.up_to_date
          update_extmark(package, line, display, hl_group)
        else
          update_extmark(package, line, "Invalid version", ComposerCost.config.highlight_groups.error)
        end
      else
        update_extmark(package, line, "Failed to fetch", ComposerCost.config.highlight_groups.error)
      end
    end)
  end)
end

ComposerCost.paint = function()
  local co = coroutine.create(function()
    local data = get_composer_data()
    if not data then
      return
    end

    local function process_section(section)
      for package, version in pairs(data[section] or {}) do
        local line = vim.fn.search('"' .. package .. '"', "n") - 1
        process_package(package, version, line)
        coroutine.yield()
      end
    end

    process_section("require")
    if ComposerCost.config.check_dev_dependencies then
      process_section("require-dev")
    end
  end)

  local function resume()
    if coroutine.status(co) ~= "dead" then
      local ok, err = coroutine.resume(co)
      if not ok then
        print("Error in coroutine: " .. err)
      else
        vim.schedule(resume)
      end
    end
  end

  resume()
end

return ComposerCost
