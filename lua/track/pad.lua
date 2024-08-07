local Pad = {}
Pad.__index = Pad
setmetatable(Pad, {
  __call = function(class, ...)
    local self = setmetatable({}, class)
    self:_new(...)
    return self
  end,
})

local A = vim.api
local V = vim.fn
local if_nil = vim.F.if_nil

local Mark = require("track.model.mark")

local util = require("track.util")
local state = require("track.state")

local utils = require("telescope.utils")
local strings = require("plenary.strings")

local enum = require("track.dev.enum")
local CLASS = enum.CLASS
local TERM = enum.M_TYPE.TERM
local HTTP = enum.M_TYPE.HTTP
local HTTPS = enum.M_TYPE.HTTPS
local DIR = enum.M_TYPE.DIR
local MAN = enum.M_TYPE.MAN
local FILE = enum.M_TYPE.FILE
local NO_EXIST = enum.M_TYPE.NO_EXIST

function Pad:_new(opts)
  local types = type(opts)
  assert(types == "table", "expected table")

  self.switch_directory = if_nil(opts.switch_directory, false)
  self.serial_map = if_nil(opts.serial_map, false)
  self.path_display = if_nil(opts.path_display, {})
  self.mappings = if_nil(opts.mappings, {})
  self.entries = if_nil(opts, {})
  self.icons = opts.icons
  self.disable_devicons = if_nil(opts.disable_devicons, true)
  self.disable_status = if_nil(opts.disable_status, true)
  self.color_devicons = opts.color_devicons

  self.branch = if_nil(opts.branch, select(2, util.root_and_branch({}, true)))
  self.buffer = A.nvim_create_buf(false, false)
  self.namespace = A.nvim_create_namespace("TrackPad")
  self.hooks = opts.hooks
  self.window = nil

  self.mappings.n["<cr>"] = function()
    if self:hidden() then return end
    local mark = Pad.parse_line(A.nvim_get_current_line(), self.icons, self.disable_devicons)
    if not mark then return end
    self:close()
    if util.to_root_entry(mark, self) then return end
    self.hooks.on_choose(mark)
  end

  self.config = opts.config
  self.config.title = string.format(" %s ", strings.truncate(self.branch.name, math.floor(self.config.width / 2)))
  self.config.row = (vim.o.lines - self.config.height - 2) / 2
  self.config.col = (vim.o.columns - self.config.width) / 2

  A.nvim_buf_set_option(self.buffer, "filetype", "track")
  A.nvim_buf_set_name(self.buffer, self.branch.name)

  for mode, maps in pairs(self.mappings) do
    for key, action in pairs(maps) do
      vim.keymap.set(mode, key, function() action(self) end, { silent = true, buffer = self.buffer })
    end
  end

  if opts.auto_resize then
    A.nvim_create_autocmd("VimResized", {
      buffer = self.buffer,
      group = require("track").GROUP,
      callback = function()
        if not self:hidden() then
          self.config.row = (vim.o.lines - self.config.height - 2) / 2
          self.config.col = (vim.o.columns - self.config.width) / 2
          A.nvim_win_set_config(self.window, self.config)
        end
      end,
    })
  end

  A.nvim_buf_attach(self.buffer, false, {
    on_lines = function()
      if self.serial_map then self:apply_serial() end
    end,
  })

  self._NAME = CLASS.PAD
end

function Pad.make_entry(index, view_mark, icons, disable_devicons, color_devicons)
  local entry = { index = index, value = view_mark }
  local icon, group = util.get_icon(entry.value, icons, {
    disable_devicons = disable_devicons,
    color_devicons = color_devicons,
  })
  entry.icon = icon
  entry.group = group

  entry.display = (disable_devicons and "" or icon .. " ") .. entry.value.uri
  entry.range = { { { 0, #icon }, entry.group }, "TrackPadEntry" }
  return entry
end

function Pad.parse_line(line, icons, disable_devicons)
  local trimmed = vim.trim(line)
  if trimmed ~= "" then
    local mark
    if disable_devicons then
      mark = Mark({ uri = trimmed })
    else
      local icon, content = line:match("^([^%s]+)%s(.+)$")
      if icon and not utils.is_uri(icon) then
        mark = Mark({ uri = content })
        if
          not util.icon_exists(icon, icons)
          and util.get_icon(mark, icons, { disable_devicons = disable_devicons }) ~= icon
        then
          mark.uri = trimmed
        end
      else
        mark = Mark({ uri = trimmed })
      end
    end
    return mark
  end
end

function Pad:apply_status()
  local lines = A.nvim_buf_get_lines(self.buffer, 0, -1, true)
  for index, line in ipairs(lines) do
    local row = index - 1
    local mark = Pad.parse_line(line, self.icons, self.disable_devicons)
    if mark then
      local absolute = mark:absolute()
      local allowed = vim.tbl_contains({ TERM, MAN, HTTP, HTTPS }, mark.type)

      local marker, marker_hl = self.icons.accessible, "TrackPadAccessible"
      if not mark:readable() then
        marker, marker_hl = self.icons.inaccessible, "TrackPadInaccessible"
      end

      if allowed then
        marker, marker_hl = self.icons.locked, "TrackPadLocked"
      elseif not mark:exists() then
        marker, marker_hl = self.icons.missing, "TrackPadMissing"
      end

      if self._focused == absolute then
        marker, marker_hl = self.icons.focused, "TrackPadFocused"
      end

      local listed, listed_hl = self.icons.unlisted, "TrackPadMarkUnlisted"
      local buffers = V.getbufinfo({ bufloaded = 1 })
      for _, info in ipairs(buffers) do
        if info.name == absolute and info.listed == 1 then
          listed, listed_hl = self.icons.listed, "TrackPadMarkListed"
          break
        end
      end

      A.nvim_buf_set_extmark(self.buffer, self.namespace, row, 0, {
        sign_text = marker,
        sign_hl_group = marker_hl,
        number_hl_group = marker_hl,
      })

      A.nvim_buf_set_extmark(self.buffer, self.namespace, row, 0, {
        virt_text = { { listed, listed_hl } },
        virt_text_pos = "right_align",
      })
    end
  end
end

function Pad:apply_serial()
  local maps = A.nvim_buf_get_keymap(self.buffer, "n")
  for _, map in ipairs(maps) do
    if map.lhs:match("^%d+$") then A.nvim_buf_del_keymap(self.buffer, "n", map.lhs) end
  end

  local lines = A.nvim_buf_get_lines(self.buffer, 0, -1, false)
  for serial, line in ipairs(lines) do
    local mark = Pad.parse_line(line, self.icons, self.disable_devicons)
    if mark then
      vim.keymap.set("n", tostring(serial), function()
        self:close()
        self.hooks.on_serial(mark, serial, self)
      end, { buffer = self.buffer })
    end
  end
end

function Pad:_extmark(line, start, finish)
  A.nvim_buf_set_extmark(self.buffer, self.namespace, line, start, {
    end_row = line,
    end_col = finish,
    conceal = "",
  })
end

function Pad:conceal_uri(line, offset, path)
  local start, finish = path:find("^%w+://")
  if start and finish then
    start = offset
    finish = finish + start
    self:_extmark(line, start, finish)
  end
end

function Pad:conceal_term(line, offset, path)
  self:conceal_uri(line, offset, path)
  local start, finish = path:find("^(term://.+//)%d+?:.*$")
  if start and finish then
    self:_extmark(line, start + offset - 1, finish + offset)
  else
    start, finish = path:find("^(term://.+//)")
    if start and finish then self:_extmark(line, start + offset - 1, finish + offset) end
  end

  local count = 1
  start, finish = nil, nil
  while true do
    start, finish = path:find("\\|", count)
    if start == nil then break end
    self:_extmark(line, start + offset - 1, finish + offset - 1)
    count = finish + 1
  end
end

function Pad:conceal_path(line, offset, path)
  local normp = vim.split(path, "/", { plain = true })
  local tranp = vim.split(utils.transform_path(self, path), "/", { plain = true })

  if #tranp ~= #normp or normp[#normp] ~= tranp[#tranp] then return end
  table.remove(tranp)
  table.remove(normp)

  local index = 1
  local pointer = offset
  while index <= #tranp do
    pointer = pointer + #tranp[index]
    local start = pointer
    pointer = pointer + #normp[index] - #tranp[index]
    if (pointer - start) ~= #normp[index] then self:_extmark(line, start, pointer) end
    pointer = pointer + 1
    index = index + 1
  end
end

---@todo
function Pad:theme() end

-- stylua: ignore
function Pad:render()
  self:clean()
  self:clear()
  local view_marks = self.branch.views()
  for index, view_mark in ipairs(view_marks) do
    local entry = Pad.make_entry(index, view_mark, self.icons, self.disable_devicons, self.color_devicons)
    local mark = entry.value
    local line = index - 1
    local range = entry.range
    if entry.value:absolute() == self._focused then range[2] = range[2] .. "Focused" end
    table.insert(self.entries, index, entry)

    A.nvim_buf_set_lines(self.buffer, line, line, true, { entry.display })
    if not self.disable_devicons then
      A.nvim_buf_add_highlight(self.buffer, self.namespace, range[1][2], line, range[1][1][1], range[1][1][2])
    end

    local start = range[1][1][2] + (self.disable_devicons and 0 or 1)
    A.nvim_buf_add_highlight(self.buffer, self.namespace, range[2], line, start, start + #mark.uri)
    if mark.type == FILE or mark.type == DIR or mark.type == NO_EXIST then
      self:conceal_path(line, start, mark.uri)
    elseif mark.type == TERM then
      self:conceal_term(line, start, mark.uri)
    else
      self:conceal_uri(line, start, mark.uri)
    end
  end
  if not self.disable_status then self:apply_status() end
  if self.serial_map then self:apply_serial() end
end

function Pad:sync(save)
  self.branch:clear()
  local lines = A.nvim_buf_get_lines(self.buffer, 0, -1, true)
  for _, line in ipairs(lines) do
    local mark = Pad.parse_line(line, self.icons, self.disable_devicons)
    if mark then self.branch:add_mark(mark) end
  end
  self:render()
  if save then state.save() end
end

function Pad:hidden() return not self.window or not A.nvim_win_is_valid(self.window) end

-- stylua: ignore
function Pad:open()
  if not self:hidden() then return end
  self._focused = util.parsed_bufname()
  self.window = A.nvim_open_win(self.buffer, true, self.config)
  A.nvim_win_set_option(self.window, "winhighlight", "SignColumn:NormalFloat,CursorLineSign:NormalFloat,FloatTitle:TrackPadTitle,FloatBorder:NormalFloat")
  A.nvim_win_set_option(self.window, "number", true)
  A.nvim_win_set_option(self.window, "cursorline", true)
  if not self.disable_status then A.nvim_win_set_option(self.window, "numberwidth", 3) end
  self:render()
end

function Pad:close()
  if self:hidden() then return end
  A.nvim_win_close(self.window, true)
  self.hooks.on_close(self)
  if self.save_on_close then state.save() end
  self.window = nil
end

function Pad:toggle()
  if self:hidden() then
    self:open()
    return
  end
  self:close()
end

function Pad:exists() return self.buffer and A.nvim_buf_is_valid(self.buffer) end

function Pad:delete()
  if not self:exists() then return end
  A.nvim_buf_delete(self.buffer, { force = true })
end

function Pad:clean(begin, finish) A.nvim_buf_clear_namespace(self.buffer, self.namespace, begin or 0, finish or -1) end

function Pad:clear() A.nvim_buf_set_lines(self.buffer, 0, -1, true, {}) end

return Pad
