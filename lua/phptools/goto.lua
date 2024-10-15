local M = {}

local symbol_cache = {}

local function find_php_client()
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == "intelephense" or client.name == "phpactor" then
      return client
    end
  end
end

local function match_method(method_name, symbols)
  for _, symbol in ipairs(symbols) do
    if symbol.text:match("^%[Method%]") then
      local symbol_method = symbol.text:match("%[Method%] (.+)")
      if symbol_method == method_name or
          (not method_name and symbol_method == "__invoke") or
          symbol_method:match("^" .. vim.pesc(method_name) .. "%(") then
        return symbol
      end
    end
  end
end

local function open_filename(filename)
  local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(filename))
  if vim.api.nvim_get_current_buf() ~= bufnr then
    vim.cmd.buffer(bufnr)
  end
end

local function handle_error(msg, client_id)
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.WARN)
    if client_id then
      vim.lsp.stop_client(client_id)
    end
  end)
end

function M.go(client, is_new_instance, full_class, method)
  local class_parts = vim.split(full_class, "\\")
  local class = class_parts[#class_parts]

  local function get_class_location()
    if symbol_cache[full_class] then
      return symbol_cache[full_class]
    end

    local resp = client.request_sync("workspace/symbol", { query = class }, nil)
    if not resp or not resp.result then
      return nil
    end

    for _, location in ipairs(resp.result) do
      if location.location
          and location.containerName .. "\\" .. location.name == full_class
          and vim.lsp.util._get_symbol_kind_name(location.kind) == "Class" then
        symbol_cache[full_class] = location
        return location
      end
    end
  end

  local class_location = get_class_location()

  if not class_location then
    return handle_error("Could not find class for : " .. full_class, is_new_instance and client.id)
  end

  open_filename(vim.uri_to_fname(class_location.location.uri))

  local params = vim.lsp.util.make_position_params(0)
  if is_new_instance then
    vim.lsp.buf_attach_client(0, client.id)
  end

  vim.lsp.buf_request(0, "textDocument/documentSymbol", params, function(method_err, method_server_result, _, _)
    if method_err then
      return handle_error("Error when finding workspace symbols: " .. method_err.message, is_new_instance and client.id)
    end

    local method_locations = vim.lsp.util.symbols_to_items(method_server_result or {}, 0) or {}
    if vim.tbl_isempty(method_locations) then
      return handle_error(string.format("Empty response looking for method: %s", method or "__invoke"),
        is_new_instance and client.id)
    end

    local method_location = match_method(method, method_locations)

    if not method_location then
      return handle_error(string.format("Could not find method: %s", method or "__invoke"), is_new_instance and client
        .id)
    end

    vim.schedule(function()
      pcall(vim.api.nvim_win_set_cursor, 0, { method_location.lnum, method_location.col - 1 })
      vim.cmd "normal zt"
    end)

    if is_new_instance then
      vim.lsp.stop_client(client.id)
    end
  end)
end

function M.goto_definition()
  local current_word = vim.fn.expand("<cword>")
  local full_class, method = current_word:match("([^:]+)::([^:]+)")

  if not full_class then
    full_class = current_word
    method = nil
  end

  local client = find_php_client()

  if client then
    M.go(client, false, full_class, method)
  else
    vim.schedule(function()
      vim.notify("No active PHP LSP client found", vim.log.levels.WARN)
    end)
  end
end

return M
