---@diagnostic disable: param-type-mismatch
local Mark = {}
Mark.__index = Mark
setmetatable(Mark, {
  ---@return Mark
  __call = function(class, ...)
    local self = setmetatable({}, class)
    self:_new(...)
    return self
  end,
  __eq = function(a, b) return a:absolute() == b:absolute() end,
})

local V = vim.fn
local U = vim.loop
local A = vim.api
local if_nil = vim.F.if_nil

local util = require("track.util")
local enum = require("track.dev.enum")
local DIR = enum.M_TYPE.DIR
local FILE = enum.M_TYPE.FILE
local NO_EXIST = enum.M_TYPE.NO_EXIST
local CLASS = enum.CLASS

---Create a new `Mark` object.
---@param opts MarkFields Available mark attributes/fields.
function Mark:_new(opts)
  local types = type(opts)
  assert(types == "table", "expected: opts.opts to be table found " .. types)
  assert(opts.uri and type(opts.uri) == "string", "opts.path: string cannot be nil")

  self.range = { 1, 0 }
  self:update_range()
  self.uri = opts.uri
  self.type = if_nil(opts.type, util.filetype(opts.uri))
  self._NAME = CLASS.MARK
end

function Mark:update_range()
  self.range = self:absolute() == A.nvim_buf_get_name(0) and A.nvim_win_get_cursor(0) or self.range
end

function Mark:absolute()
  local path = self.uri
  if self.type ~= FILE and self.type ~= DIR then return path end
  path = vim.fs.normalize(path)
  return if_nil((U.fs_realpath(path)), V.fnamemodify(path, ":p"))
end

function Mark:readable()
  if self.type ~= FILE and self.type ~= DIR then return true end
  return not not U.fs_access(self:absolute(), "R")
end

---Check if the mark URI exists. True if it does, false otherwise.
---@return boolean
function Mark:exists()
  if self.type == NO_EXIST then return false end
  if self.type ~= FILE and self.type ~= DIR then return true end
  return not not U.fs_realpath(self:absolute())
end

function Mark:symbolic()
  if self.type ~= FILE and self.type ~= DIR then return false end
  return if_nil(U.fs_lstat(self:absolute()), {}).type == "link"
end

return Mark
