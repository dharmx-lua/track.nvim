local M = {}

local util = require("track.util")
local if_nil = vim.F.if_nil

-- TODO: Implement validation (vim.validate) and config fallback.
-- TODO: Defaults (M.defaults) will be used if config values are invalid.
-- TODO: Implement exclude buffer names.

---Default **track.nvim** opts.
---@type TrackOpts
M._defaults = {
  save_path = vim.fn.stdpath("state") .. "/track.json",
  root_path = true,
  bundle_label = true,
  pickers = {
    bundles = {
      save_on_close = true,
      prompt_prefix = "   ",
      selection_caret = "   ",
      previewer = false,
      initial_mode = "normal", -- alternatively: "insert"
      sorting_strategy = "ascending",
      results_title = false,
      layout_config = {
        prompt_position = "top",
        preview_cutoff = 1,
        width = function(_, max_col, _) return math.min(max_col, 70) end,
        height = function(_, _, max_line) return math.min(max_line, 15) end,
      },
      hooks = {
        on_close = util.mute,
        on_open = util.mute,
        on_choose = function(status, opts)
          local selected = status.picker:get_selection()
          if not selected then return end
          local root, _ = util.root_and_bundle()
          root:change_main_bundle(selected.value.label)
        end,
      },
      attach_mappings = function(_, map)
        local actions = require("telescope.actions")
        map("n", "q", actions.close)
        map("n", "v", actions.select_all)

        local track_actions = require("telescope._extensions.track.actions")
        map("n", "D", actions.select_all + track_actions.delete_bundle)
        map("n", "dd", track_actions.delete_bundle)
        map("i", "<C-D>", track_actions.delete_bundle)
        map("i", "<C-E>", track_actions.change_bundle_label)
        return true -- compulsory
      end,
      icons = {
        separator = " ┃ ",
        main = " ",
        alternate = " ",
        inactive = " ",
        mark = "",
        history = "",
      }
    },
    views = {
      save_on_close = true, -- save when the view telescope picker is closed
      selection_caret = "   ",
      path_display = {
        absolute = false, -- /home/name/projects/hello/mark.lua -> hello/mark.lua
        shorten = 1, -- /aname/bname/cname/dname.e -> /a/b/c/dname.e
      },
      prompt_prefix = "   ",
      previewer = false,
      initial_mode = "normal", -- alternatively: "insert"
      results_title = false,
      sorting_strategy = "ascending",
      layout_config = {
        prompt_position = "top",
        preview_cutoff = 1,
        width = function(_, max_col, _) return math.min(max_col, 70) end,
        height = function(_, _, max_line) return math.min(max_line, 15) end,
      },
      hooks = {
        on_close = util.mute,
        on_open = util.mute,
        on_choose = function(status, _)
          local entries = if_nil(status.picker:get_multi_selection(), {})
          if #entries == 0 then table.insert(entries, status.picker:get_selection()) end
          for _, entry in ipairs(entries) do util.open_entry(entry) end
        end,
      },
      attach_mappings = function(_, map)
        local actions = require("telescope.actions")
        map("n", "q", actions.close)
        map("n", "v", actions.select_all)

        local track_actions = require("telescope._extensions.track.actions")
        map("n", "D", actions.select_all + track_actions.delete_view)
        map("n", "dd", track_actions.delete_view)
        map("n", "s", track_actions.change_mark_view)
        map("n", "<C-b>", track_actions.delete_buffer)
        map("n", "<C-j>", track_actions.move_view_next)
        map("n", "<C-k>", track_actions.move_view_previous)

        map("i", "<C-d>", track_actions.delete_view)
        map("i", "<C-n>", track_actions.move_view_next)
        map("i", "<C-p>", track_actions.move_view_previous)
        map("i", "<C-e>", track_actions.change_mark_view)
        return true -- compulsory
      end,
      disable_devicons = false,
      icons = {
        locked = " ",
        separator = " ",
        terminal = " ",
        manual = " ",
        site = " ",
        missing = " ",
        accessible = " ",
        inaccessible = " ",
        focused = " ",
        listed = "",
        unlisted = "≖",
        file = "",
        directory = "",
      },
    },
  },
  log = {
    plugin = "track",
    level = "warn",
  },
  -- dev features / not implemented
  disable_history = true,
  maximum_history = 10,
  pad = {
    icons = {
      saved = "",
      save = "",
    },
    serial_maps = true,
    save_on_close = true,
    auto_create = true,
    save_on_hide = true,
    hooks = {
      on_choose = util.open_entry,
      on_serial_choose = util.open_entry,
    },
    window = {
      style = "minimal",
      border = "solid",
      focusable = true,
      relative = "editor",
      width = 60,
      height = 10,
      title_pos = "left",
    },
  },
}

---Current **track.nvim** opts. This will be initially the same as `defaults`.
---@type TrackOpts
M._current = vim.deepcopy(M._defaults)

---Merge `opts` with current track opts (`M._current`).
---@param opts TrackOpts
function M.merge(opts)
  ---@type TrackOpts
  opts = if_nil(opts, {})
  M._current = vim.tbl_deep_extend("keep", opts, M._current)
end

---Merge `opts` with current track picker opts (`M._current.pickers`).
---@param opts TrackPickers
function M.merge_pickers(opts)
  ---@type TrackPickers
  opts = if_nil(opts, {})
  M._current.pickers = vim.tbl_deep_extend("keep", opts, M._current.pickers)
end

---@param opts TrackPad
function M.merge_pad(opts)
  ---@type TrackPad
  opts = if_nil(opts, {})
  M._current.pad = vim.tbl_deep_extend("keep", opts, M._current.pad)
end

---Merge `opts` with current track opts and return it. This will not write to `M._current`.
---@param opts TrackOpts
---@return TrackOpts
function M.extend(opts) return vim.tbl_deep_extend("keep", opts, M._current) end

---Merge `opts` with current track picker opts and return it. This will not write to `M._current.pickers`.
---@param opts TrackPickers
---@return TrackPickers
function M.extend_pickers(opts) return vim.tbl_deep_extend("keep", opts, M._current.pickers) end

---@param opts TrackPad
---@return TrackPad
function M.extend_pad(opts) return vim.tbl_deep_extend("keep", opts, M._current.pad) end

---Return current track config.
---@return TrackOpts
function M.get() return M._current end

---Return current track pickers config.
---@return TrackPickers
function M.get_pickers() return M._current.pickers end

---@return TrackPad
function M.get_pad() return M._current.pad end

return M
