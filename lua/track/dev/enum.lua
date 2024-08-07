local M = {}

M.M_TYPE = {
  NO_EXIST = "no_exist",
  NO_ACCESS = "no_access",
  ERROR = "error",
  TERM = "term",
  FILE = "file",
  RANGE = "range",
  DIR = "directory",
  DEFAULT = "default",
  HTTP = "http",
  HTTPS = "https",
  MAN = "man",
}
setmetatable(M.M_TYPE, { __index = function(self) return self.DEFAULT end })

M.CLASS = {
  MARK = "mark",
  BRANCH = "branch",
  ROOT = "root",
  PAD = "pad",
}

return M
