-- main module file
local mthd = require("phpUtils.method")
local clss = require("phpUtils.class")
local cmpsr = require("phpUtils.composer")

local M = {}

M.method = function()
    mthd.method()
end

M.class = function()
    clss.class()
end

M.commands = function()
    cmpsr.scripts()
end


local config = {
    uiOverwrite= false,
    scrictType = true,
  }


  M.config = config

  M.setup = function(args)
    M.config = vim.tbl_deep_extend("force", M.config, args or {})
  end



return M
