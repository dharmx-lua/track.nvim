local M = {}

local config = require("track.config").get()

local Root = require("track.model.root")
local Mark = require("track.model.mark")
local Branch = require("track.model.branch")
local P = require("plenary.path")

local log = require("track.dev.log")

---Main state of track.nvim. It tracks all roots.
---@type table<string, Root>
---@private
M._roots = {}

---Add the `__call` metatable to `M._roots` table.
---@param roots table<string, Root>
---@private
function M._callize_roots(roots)
  setmetatable(roots, {
    ---Returns either a list of root paths or, a list of `Root` instances.
    ---@param self table<string, Root> The a map of `string: Root`.
    ---@param action "string"|"instance" return a list of either Root.path[] or, Root[].
    ---@return string[]|Root[]
    __call = function(self, action)
      if action == "string" then return vim.tbl_keys(self) end
      return vim.tbl_values(self)
    end,
  })
end
M._callize_roots(M._roots)

---If `TrackConfig.savepath` has been loaded (merged) into `M._roots` then `true` else `false`.
---@private
M.loaded = false
---@private

---@type Path
local save_path = P:new(config.save_path)

---Clear all recorded roots. This will clear histories as well.
function M.wipe()
  M._roots = {}
  M._callize_roots(M._roots)
end

-- Roots parser helpers. {{{
---Helper that parses marks and wraps raw mark fields into a `Mark` instance. As a side-effect any extra values sneaked in will be ignored.
---@param marks {path: string, label: string, type: MarkType}[]
---@return Mark[]
local function parse_marks(marks)
  local store = {}
  for path, mark in pairs(marks) do
    store[path] = Mark({
      uri = mark.uri,
      type = mark.type,
    })
  end
  return store
end

---Helper that parsers branches and wraps raw branch into a `Branch` instance.
---@param branches {name: string, disable_history?: boolean, maximum_history: number, marks: table<string, Mark>, views: Mark[]}[]
---@return Branch[]
local function parse_branches(branches)
  local store = {}
  for name, branch in pairs(branches) do
    store[name] = Branch({
      name = branch.name,
      disable_history = branch.disable_history,
      maximum_history = branch.maximum_history,
    })

    store[name].marks = parse_marks(branch.marks)
    store[name].views = branch.views

    store[name]:_callize_views()
    store[name]:_callize_marks()
  end
  return store
end
-- }}}

---Load a save file. The decoded JSON will be merged/overwritten to `M._roots` table.
---@param action "wipe"|"extend" Wipe will clear `M._roots` and then assign the decoded values. Merge will extend existing `M._roots` value.
---@param loadpath string Path to save file that should be loaded.
---@param on_load? function Run this callback after the save file is loaded.
function M.load_save(action, loadpath, on_load)
  if not save_path:exists() then
    log.warn("State.load_save(): " .. save_path.filename .. " does not exist")
    return
  end

  ---@diagnostic disable-next-line: cast-local-type
  loadpath = P:new(loadpath)
  local data = vim.trim(loadpath:read()) -- strip leading and trailing whitespaces
  if data == "" then
    log.warn("State.load_save(): " .. save_path.filename .. " is empty")
    return
  end

  -- action == "wipe" will clear the current state (M._roots)
  -- and then parse the supplied savefile
  -- otherwise it will be merged with current state (maybe I should remove this?)
  local roots = vim.F.if_nil(vim.json.decode(data), {})
  if action == "wipe" then M.wipe() end
  assert(action == "extend" or action == "wipe", "action: string[extend|wipe]")

  ---@diagnostic disable-next-line: param-type-mismatch
  for path, root in pairs(roots) do
    M._roots[path] = Root({
      path = root.path,
      label = root.label,
      main = root.main,
      disable_history = root.disable_history,
      maximum_history = root.maximum_history,
    })
    M._roots[path].branches = parse_branches(root.branches) -- delegate to helper
    M._roots[path]:_callize_branches()

    -- private
    M._roots[path].stashed = root.stashed
    M._roots[path].previous = root.previous
  end
  log.info("State.load_save(): loaded state from " .. save_path.filename)
  if on_load then on_load(M._roots) end
end

---Reload and merge `Config.savepath` path into `M._roots` again.
---@param on_reload? function Callback that gets called after reload.
function M.reload(on_reload)
  M.load_save("extend", save_path.filename, on_reload)
  log.info("State.reload(): reloaded " .. save_path.filename)
end

-- you will see this called practically everywhere in core.lua

---Load and assign `Config.savepath` path into `M._roots`. This can only be called once.
---@param on_load? function Callback that gets called after load.
function M.load(on_load)
  if M._loaded then return end
  M._loaded = true -- allow calling this only once.
  log.info("State.load(): loaded state from " .. save_path.filename)
  M.reload(on_load)
end

---Save current state of `M._roots` into `Config.savepath`.
---@param before_save? function Callback that is called exactly before changes are written in `Config.savepath`.
---@param on_save? function Callback that is called after changes are written to `Config.savepath`.
function M.save(before_save, on_save)
  if not save_path:exists() then
    log.warn("M.save(): " .. save_path.filename .. " does not exist. Creating...")
    save_path:touch({ parents = true })
  end

  -- before_save seems too much?
  if before_save and before_save() then return end
  local encoded = vim.json.encode(M._roots)
  save_path:write(encoded, "w")
  log.info("State.save(): saved current state into " .. save_path.filename)
  if on_save then on_save() end
end

---Remove or clear the save file.
---@param clean? boolean
function M.remove(clean)
  if clean then
    -- empty JSON object
    save_path:write("{}", "w")
    log.info("State.remove(): cleared " .. save_path.filename)
    return
  end
  log.info("State.remove(): removed " .. save_path.filename)
  save_path:rm()
end

return M
