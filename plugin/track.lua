if vim.version().minor < 8 then
  vim.notify("track.nvim requires at least nvim 0.8.0")
  return
end

if vim.g.loaded_track == 1 then return end
vim.g.loaded_track = 1

local V = vim.fn
local A = vim.api
local if_nil = vim.F.if_nil

local cmd = A.nvim_create_user_command
local function HI(...) A.nvim_set_hl(0, ...) end

cmd("Track", function(data)
  if data.bang then
    local buffers = V.getbufinfo({ buflisted = 1 })
    for _, info in ipairs(buffers) do
      local name = A.nvim_buf_get_name(info.bufnr)
      if name ~= "" then vim.cmd.Mark(name) end
    end
    return
  end

  local args = data.fargs
  if args[1] == "save" then
    require("track.state").save()
  elseif args[1] == "load" then
    require("track.state").load()
  elseif args[1] == "savefile" then
    assert(args[2] and type(args[2]) == "string", "Needs a path value.")
    require("track.state").load_save("wipe", args[2])
  elseif args[1] == "reload" then
    require("track.state").reload()
  elseif args[1] == "wipe" then
    require("track.state").wipe()
  elseif args[1] == "remove" then
    require("track.state").remove()
  elseif args[1] == "branches" then
    require("telescope").extensions.track.branches()
  elseif args[1] == "views" then
    require("telescope").extensions.track.views()
  else
    require("track.core").pad:toggle()
  end
end, {
  desc = "track.nvim state operations.",
  nargs = "*",
  bang = true,
  complete = function()
    return {
      "save",
      "load",
      "savefile",
      "reload",
      "wipe",
      "remove",
      "menu",
      "views",
      "pad",
      "branches",
    }
  end,
})

cmd("Mark", function(data)
  local uri = vim.trim(data.args)
  uri = uri ~= "" and uri or A.nvim_buf_get_name(0)
  local uri_type = require("track.util").filetype(uri)
  local core = require("track.core")
  local P = require("plenary.path")
  if uri_type == "file" then uri = P:new(uri):make_relative(core.root_path) end
  core:mark(uri)
end, {
  complete = "file",
  desc = "Mark current file.",
  nargs = "?",
})

cmd("Unmark", function(data)
  local uri = vim.trim(data.args)
  uri = uri ~= "" and uri or A.nvim_buf_get_name(0)
  local uri_type = require("track.util").filetype(uri)
  local core = require("track.core")
  local P = require("plenary.path")
  if uri_type == "file" then uri = P:new(uri):make_relative(core.root_path) end
  core:unmark(uri)
end, {
  complete = function()
    local _, branch = require("track.util").root_and_branch()
    return branch and branch.views or {}
  end,
  desc = "Unmark current file.",
  range = true,
  nargs = "?",
})

cmd("NewBranch", function()
  local core = require("track.core")
  core:stash()
  core(require("track.util").cwd())
end, {
  complete = function()
    local root, _ = require("track.util").root_and_branch()
    return root and root.branches("string") or {}
  end,
  desc = "Stash current branch.",
  nargs = "?",
})

cmd("RMBranch", function(data)
  local name = data.args
  local core = require("track.core")
  core:delete(name ~= "" and name or nil)
  core(require("track.util").cwd())
end, {
  desc = "Delete branch.",
  nargs = "?",
  complete = function()
    local root, _ = require("track.util").root_and_branch()
    return root and root.branches("string") or {}
  end,
})

cmd("SwapBranch", function(data)
  local core = require("track.core")
  if data.bang then
    core:restore()
  else
    core:alternate()
  end
  core(require("track.util").cwd())
end, {
  desc = "Alternate/Restore stashed branch.",
  bang = true,
  nargs = 0,
})

cmd("OpenMark", function(data)
  local args = vim.trim(data.args)
  ---@diagnostic disable-next-line: cast-local-type
  args = if_nil(tonumber(args), args)
  require("track.core"):select(args, require("track.config").get().on_open)
end, {
  desc = "Select a mark (view)",
  nargs = 1,
  complete = function()
    local _, branch = require("track.util").root_and_branch()
    return branch and branch.views or {}
  end,
})

-- Highlights {{{
HI("TrackPadTitle", { link = "TelescopeResultsTitle" })
HI("TrackPadEntryFocused", { foreground = "#7AB0DF" })
HI("TrackPadAccessible", { foreground = "#79DCAA" })
HI("TrackPadInaccessible", { foreground = "#F87070" })
HI("TrackPadFocused", { foreground = "#7AB0DF" })
HI("TrackPadMarkListed", { foreground = "#4B5259" })
HI("TrackPadMarkUnlisted", { foreground = "#C397D8" })
HI("TrackPadMissing", { foreground = "#FFE59E" })
HI("TrackPadLocked", { foreground = "#E37070" })
HI("TrackPadDivide", { foreground = "#4B5259" })
HI("TrackViewsRanged", { foreground = "#54CED6" })

HI("TrackViewsAccessible", { foreground = "#79DCAA" })
HI("TrackViewsInaccessible", { foreground = "#F87070" })
HI("TrackViewsFocusedDisplay", { foreground = "#7AB0DF" })
HI("TrackViewsFocused", { foreground = "#7AB0DF" })
HI("TrackViewsIndex", { foreground = "#54CED6" })
HI("TrackViewsMarkListed", { foreground = "#4B5259" })
HI("TrackViewsMarkUnlisted", { foreground = "#C397D8" })
HI("TrackViewsMissing", { foreground = "#FFE59E" })
HI("TrackViewsFile", { foreground = "#FFE59E" })
HI("TrackViewsDirectory", { foreground = "#FFE59E" })
HI("TrackViewsSite", { foreground = "#66B3FF" })
HI("TrackViewsTerminal", { foreground = "#36C692" })
HI("TrackViewsManual", { foreground = "#5FB0FC" })
HI("TrackViewsDivide", { foreground = "#4B5259" })
HI("TrackViewsLocked", { foreground = "#E37070" })

HI("TrackBranchesInactive", { foreground = "#4B5259" })
HI("TrackBranchesDisplayInactive", { foreground = "#4B5259" })
HI("TrackBranchesMain", { foreground = "#7AB0DF" })
HI("TrackBranchesDisplayMain", { foreground = "#7AB0DF" })
HI("TrackBranchesAlternate", { foreground = "#36C692" })
HI("TrackBranchesDisplayAlternate", { foreground = "#79DCAA" })
HI("TrackBranchesMark", { foreground = "#FFE59E" })
HI("TrackBranchesHistory", { foreground = "#F87070" })
HI("TrackBranchesDivide", { foreground = "#151A1F" })
HI("TrackBranchesIndex", { foreground = "#54CED6" })
-- }}}
