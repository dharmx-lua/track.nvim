---@diagnostic disable: cast-local-type
local M = {}

local U = vim.loop
local V = vim.fn
local A = vim.api
local if_nil = vim.F.if_nil

local M_TYPE = require("track.dev.enum").M_TYPE
local TERM = M_TYPE.TERM
local DEFAULT = M_TYPE.DEFAULT
local RANGE = M_TYPE.RANGE
local HTTP = M_TYPE.HTTP
local HTTPS = M_TYPE.HTTPS
local DIR = M_TYPE.DIR
local MAN = M_TYPE.MAN
local FILE = M_TYPE.FILE
local NO_EXIST = M_TYPE.NO_EXIST
local NO_ACCESS = M_TYPE.NO_ACCESS
local ERROR = M_TYPE.ERROR

---Dummy function that does noting.
function M.mute() end

function M.open_entry(mark)
  if mark.type == HTTPS or mark.tyoe == HTTP then
    vim.fn.jobstart({ "xdg-open", mark:absolute() }, { detach = true })
    return
  end
  vim.cmd("confirm edit " .. mark:absolute())
end

---@return string
function M.filetype(uri)
  local uri_type = if_nil(uri:match("^(%w+)://"), FILE)
  if uri_type == FILE then
    local tokens = vim.split(uri, ":")
    if #tokens > 1 then return RANGE end
    uri = vim.fs.normalize(uri)
    local stat, _, e = U.fs_stat(uri)
    if e == "EACCES" then
      return NO_ACCESS
    elseif e == "ENOENT" then
      return NO_EXIST
    else
      return stat and stat.type or ERROR
    end
  end
  return vim.trim(uri_type) == "" and DEFAULT or M_TYPE[uri_type:upper()]
end

-- stylua: ignore
function M.transform_term_uri(uri)
  return (uri:match("^term://.+//%d+:(.+)$") or uri:match("^term://.+//(.+)$") or uri:match("term://(.+)")):gsub( "\\|", "|")
end

function M.transform_man_uri(uri) return uri:match("man://(.+)") end

function M.transform_site_uri(uri) return uri:match("https?://w?w?w?%.?(.+)") end

---Get cwd. Like really.
---@return string
function M.cwd() return (U.cwd()) or vim.fn.getcwd() or vim.env.PWD end

function M.icon_exists(symbol, extra_icons)
  extra_icons = if_nil(extra_icons, {})
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then return false end
  if not devicons.has_loaded() then devicons.setup() end
  local icons = devicons.get_icons()
  for _, icon in pairs(icons) do
    if icon.icon == symbol then return true end
  end
  for _, icon in pairs(extra_icons) do
    if icon == symbol then return true end
  end
  return false
end

function M.get_icon(mark, extra_icons, opts)
  local icon, group = "", ""
  if opts.disable_devicons then return icon end

  if mark.type == TERM then
    icon, group = extra_icons.terminal, "TrackViewsTerminal"
  elseif mark.type == MAN then
    icon, group = extra_icons.manual, "TrackViewsManual"
  elseif mark.type == DIR then
    icon, group = extra_icons.directory, "TrackViewsDirectory"
  elseif mark.type == HTTP or mark.type == HTTPS then
    icon, group = extra_icons.site, "TrackViewsSite"
  else
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if not ok then
      icon, group = extra_icons.file, "TrackViewsFile"
    else
      if not devicons.has_loaded() then devicons.setup() end
      icon, group = devicons.get_icon(vim.fs.basename(mark.uri))
      if not icon or not group then
        icon, group = devicons.get_default_icon().icon, "DevIconDefault"
      end
    end
  end

  if opts.color_devicons ~= false then return icon, group end
  assert(A.nvim_strwidth(icon) < 2, "icon length should be < 2")
  return icon, ""
end

function M.clean_term_uri(uri)
  local trimmed = vim.trim(uri)
  local working = trimmed:match("^term://(.+)//%d+:.*$")
  if working then
    trimmed = trimmed:gsub("^(term://)(.+)(//)%d+:(.*)$", "%1" .. vim.fs.normalize(working) .. "%3%4")
  else
    trimmed = trimmed:gsub("^(term://.+//)%d+:(.*)$", "%1%2")
  end
  trimmed = trimmed:gsub("|", "\\|")
  return trimmed
end

function M.root_and_branch(opts, force)
  opts = if_nil(opts, {})
  opts = require("track.config").extend(opts)
  local branch_name = opts.branch_name
  local root_path = opts.root_path ~= true and opts.root_path or M.cwd()
  assert(type(root_path) == "string", "Config.root_path needs to be string")

  local state = require("track.state")
  state.load()
  local branch = nil
  local root = state._roots[root_path]
  if root and branch_name == true then
    branch = root:get_main_branch()
  elseif type(branch_name) == "string" then
    branch = root.branches[branch_name]
  elseif force then
    if not root then
      local Root = require("track.model.root")
      local new_root = Root(root_path)
      state._roots[root_path] = new_root
      root = new_root
    end
    branch = root:get_main_branch()
  end
  return root, branch
end

function M.contains(patterns, item)
  for k, v in pairs(patterns) do
    local k_type = type(k)
    if k_type == "string" then
      if v then
        if item:match(k) then return true end
      end
    elseif k_type == "number" then
      if item:match(v) then return true end
    end
  end
  return false
end

function M.parsed_bufname(buffer)
  local name = A.nvim_buf_get_name(if_nil(buffer, 0))
  local filetype = M.filetype(name)
  if filetype == FILE then
    name = U.fs_realpath(vim.fs.normalize(name))
    name = if_nil(name, V.fnamemodify(name, ":p"))
  elseif filetype == TERM then
    name = M.clean_term_uri(name)
  end
  return name
end

function M.to_root_entry(mark, opts)
  local root_path = mark:absolute()
  if #root_path > 1 then root_path = root_path:gsub("/$", "") end
  if opts.switch_directory and mark.type == DIR and require("track.state")._roots[root_path] then
    vim.cmd.doautocmd("DirChangedPre")
    U.chdir(root_path)
    vim.cmd.doautocmd("DirChanged")
    return true
  end
  return false
end

function M.to_location(row, col)
  if A.nvim_buf_line_count(0) < row then return end
  local line_len = #A.nvim_buf_get_lines(0, row - 1, row, true)[1]
  if line_len < col then col = line_len end
  A.nvim_win_set_cursor(0, { row, col })
end

return M
