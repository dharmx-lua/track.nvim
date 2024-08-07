local M = {}

local V = vim.fn

local entry_display = require("telescope.pickers.entry_display")
local utils = require("telescope.utils")
local util = require("track.util")
local make_entry = require("telescope.make_entry")

local enum = require("track.dev.enum")
local TERM = enum.M_TYPE.TERM
local HTTP = enum.M_TYPE.HTTP
local HTTPS = enum.M_TYPE.HTTPS
local MAN = enum.M_TYPE.MAN

function M.gen_from_view(opts)
  local icons = opts.icons
  local displayer = entry_display.create({
    separator = icons.separator,
    separator_hl = "TrackViewsDivide",
    items = {
      -- hardcoded
      { width = 2 },
      {},
      {},
      {},
      {},
    },
  })

  -- indicators (pretty colors, symbols and shiny things) @derhans would be displeased
  local function make_display(entry)
    local mark = entry.value
    local absolute = mark:absolute()
    local allowed = vim.tbl_contains({ TERM, MAN, HTTP, HTTPS }, mark.type)

    -- we may/may not have read permissions on that file - priority: 1
    local marker, marker_hl = icons.accessible, "TrackViewsAccessible"
    if not mark:readable() then
      marker, marker_hl = icons.inaccessible, "TrackViewsInaccessible"
    end

    -- the marked value might be deleted - priority: 2
    if allowed then
      marker, marker_hl = icons.locked, "TrackViewsLocked"
    elseif not mark:exists() then
      marker, marker_hl = icons.missing, "TrackViewsMissing"
    end

    -- file must be currently being edited - priority: 3
    local display, display_hl = absolute, ""
    if not allowed then
      display = utils.transform_path(opts, mark.uri)
    elseif mark.type == TERM then
      display = util.transform_term_uri(mark.uri)
    elseif mark.type == MAN then
      display = util.transform_man_uri(mark.uri)
    elseif mark.type == HTTPS or mark.type == HTTP then
      display = util.transform_site_uri(mark.uri)
    end

    if opts._focused == absolute then
      display_hl = "TrackViewsFocusedDisplay"
      marker, marker_hl = icons.focused, "TrackViewsFocused"
    end
    -- add more?

    local icon, icon_hl = util.get_icon(mark, icons, opts)

    -- is the buffer listed (is it opened in nvim currently)
    local listed, listed_hl = icons.unlisted, "TrackViewsMarkUnlisted"
    local buffers = V.getbufinfo({ bufloaded = 1 })
    for _, info in ipairs(buffers) do
      if info.name == absolute and info.listed == 1 then
        listed, listed_hl = icons.listed, "TrackViewsMarkListed"
        break
      end
    end

    return displayer({
      { entry.index, "TrackViewsIndex" },
      { marker, marker_hl },
      { listed, listed_hl },
      { icon, icon_hl },
      { display, display_hl },
    })
  end

  return function(entry)
    return make_entry.set_default_entry_mt({
      value = entry,
      ordinal = entry:absolute(),
      display = make_display,
    }, opts)
  end
end

function M.gen_from_branch(opts)
  ---@type Root
  local root, _ = util.root_and_branch()
  local icons = opts.icons
  local displayer = entry_display.create({
    separator = icons.separator,
    separator_hl = "TrackBranchesDivide",
    items = {
      { width = 2 }, -- hardcoded
      {}, -- views-marks
      {}, -- history-deleted
      {}, -- main / alternate / inactive
      {}, -- { remaining = true } is implied
    },
  })

  local function make_display(entry)
    ---@type Branch
    local branch = entry.value
    local display, display_hl = branch.name, "TrackBranchesInactive"
    local state, state_hl = icons.inactive, "TrackBranchesDisplayInactive"
    if root.main == branch.name then
      state, state_hl = icons.main, "TrackBranchesMain"
      display, display_hl = branch.name, "TrackBranchesDisplayMain"
    elseif root.previous == branch.name then
      state, state_hl = icons.alternate, "TrackBranchesAlternate"
      display, display_hl = branch.name, "TrackBranchesDisplayAlternate"
    end

    local mark, mark_hl = string.format("%s %s", icons.mark, #branch.views), "TrackBranchesMark"
    local history, history_hl = string.format("%s %s", icons.history, #branch.history), "TrackBranchesHistory"
    return displayer({
      { entry.index, "TrackBranchesIndex" },
      { mark, mark_hl },
      { history, history_hl },
      { state, state_hl },
      { display, display_hl },
    })
  end

  return function(entry)
    return make_entry.set_default_entry_mt({
      value = entry,
      ordinal = entry.name,
      display = make_display,
    }, opts)
  end
end

return M
