_G.sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"
_G.root = vim.fs.root(0, { "composer.json", ".git", ".env" }) or vim.uv.cwd()

function string.ucfirst(str)
  return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

function string.lcfirst(str)
  return string.lower(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

-- delete first char
function string.dltfirst(str)
  return str:sub(2)
end
