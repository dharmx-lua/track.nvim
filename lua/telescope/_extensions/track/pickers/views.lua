local M = {}

local config = require("track.config")
local util = require("track.util")
local log = require("track.log")

local state = require("track.state")
local entry_makers = require("telescope._extensions.track.entry_makers")

local actions = require("telescope.actions")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")

local tele_config = require("telescope.config")
local tele_state = require("telescope.state")

function M.resulter(opts)
  opts = vim.F.if_nil(opts, {})
  opts = config.extend_pickers({ views = opts }).views
  local _, bundle = util.root_and_bundle()
  return bundle and not bundle:empty() and bundle.views() or {}
end

-- this can be passed into picker:refresh(<finder>)
function M.finder(opts, results)
  opts = vim.F.if_nil(opts, {})
  opts = config.extend_pickers({ views = opts }).views
  return finders.new_table({
    results = results,
    entry_maker = entry_makers.gen_from_view(opts),
  })
end

local function apply_root_entry(self, entry, opts)
  local root_path = entry.value.absolute
  if root_path:len() > 1 then root_path = root_path:gsub("/$", "") end
  if opts.switch_directory and entry.value.type == "directory" and state._roots[root_path] then
    vim.cmd.doautocmd("DirChangedPre")
    vim.loop.chdir(root_path)
    vim.cmd.doautocmd("DirChanged")
    self:refresh(M.finder(opts, M.resulter(opts)), { reset_prompt = true })
    return true
  end
  return false
end

function M.picker(opts)
  opts = vim.F.if_nil(opts, {})
  opts = config.extend_pickers({ views = opts }).views
  local hooks = opts.hooks
  state.load()

  opts._focused = vim.fn.fnamemodify(vim.fn.bufname(), ":p")
  local finder = M.finder(opts, M.resulter(opts))
  if vim.tbl_isempty(finder.results) then
    vim.notify("Bundle is empty. No marks found.")
    return
  end

  local picker = pickers.new(opts, {
    prompt_title = "Views",
    finder = finder,
    sorter = tele_config.values.file_sorter(opts),
    on_complete = {
      function(self)
        if not opts.hooks.on_serial then return end
        for entry in self.manager:iter() do
          vim.keymap.set("n", tostring(entry.index), function()
            if apply_root_entry(self, entry, opts) then return end
            actions.close(self.layout.prompt.bufnr)
            opts.hooks.on_serial(entry)
          end, { buffer = self.layout.prompt.bufnr })
        end
      end,
    },
    attach_mappings = function(buffer, _)
      local self = tele_state.get_status(buffer).picker
      actions.close:enhance({
        post = function(_)
          if opts.save_on_close then
            state.save()
            log.info("Telescope.Views.picker(): closed telescope.track.views and saved state")
          end
          hooks.on_close(self)
        end,
      })
      actions.select_default:replace(function(...)
        -- add navigation controls for traversing back and forth through other roots
        -- if the exist otherwise open the directory
        local entry = self:get_selection()
        if apply_root_entry(self, entry, opts) then return end
        actions.close(...)
        hooks.on_choose(self)
      end)
      -- dynamic keymaps
      return true
    end,
  })

  hooks.on_open(opts)
  picker:find()
end

return M
