---@diagnostic disable: param-type-mismatch
---Root represents a directory in track.nvim. This is synonymous to cwd/project.
---A root will contain a map of branches and the branches will contain marks. A root will
---also contain a `main` key which (just like GIT) will be the default branch of the root.
local Root = {}
Root.__index = Root
setmetatable(Root, {
  __call = function(class, ...)
    local self = setmetatable({}, class)
    self:_new(...)
    self.new_branch(self, self.main, true)
    self._callize_branches(self)
    return self
  end,
})

local CLASS = require("track.dev.enum").CLASS
local log = require("track.dev.log")
local if_nil = vim.F.if_nil

---@type Branch
local Branch = require("track.model.branch")

---Create a new `Root` instance.
---@param opts RootFields Available root attributes/fields.
---@return Root
function Root:_new(opts)
  local types = type(opts)
  assert(types ~= "table" or types ~= "string", "expected: fields: string|table found: " .. types)
  if types == "string" then opts = { path = opts } end
  assert(opts.path and type(opts.path) == "string", "fields.path: string cannot be nil")

  self.path = opts.path
  self.label = opts.label

  self.disable_history = if_nil(opts.disable_history, true)
  self.maximum_history = if_nil(opts.maximum_history, 10)
  self.history = {}

  self.branches = {}
  self.stashed = nil -- currently stashed branch (if any)
  self.previous = nil -- previous branch (alternate)
  self._NAME = CLASS.ROOT
  ---@diagnostic disable-next-line: missing-return
  self.main = if_nil(opts.main, "main")
end

-- Metatable Setters {{{
---@private
---Helper for re-registering the `__call` metatable to `Root.branches` field.
function Root:_callize_branches()
  setmetatable(self.branches, {
    __call = function(branches, action)
      if action == "string" then return vim.tbl_keys(branches) end
      return vim.tbl_values(branches)
    end,
  })
end
-- }}}

---Create a new `Branch` inside the `Root`. No collision handling implemented. If an existing branch name
---is supplied then it will get erased with an empty one.
---@param name string The name/label of the `Branch`.
---@param main? boolean Make this the default `Branch`.
---@param marks? Mark[]|table<string, Mark> Optional List of marks.
function Root:new_branch(name, main, marks)
  assert(name and type(name) == "string", "name needs to be a string and not nil.")
  main = if_nil(main, false)
  marks = if_nil(marks, {})
  self.branches[name] = Branch(name)
  log.trace("Root.new_branch(): branch " .. name .. " has been created")

  if vim.tbl_islist(marks) then
    for _, mark in ipairs(marks) do
      self.branches[name]:add_mark(mark)
    end
  else
    self.branches[name].marks = marks
  end
  if main then self:change_main_branch(name) end
end

---Change the default branch. Current branch will be saved into `Root.previous` variable.
---@param new_main string New default `Branch`.
function Root:change_main_branch(new_main)
  assert(new_main and type(new_main) == "string", "new_main needs to be a string|nil.")
  if not new_main then return end
  if not vim.tbl_contains(vim.tbl_keys(self.branches), new_main) then
    log.warn("Root.change_main_branch(): tried changing main to a branch " .. new_main .. " which does not exist")
    return
  end
  self.previous = self.main
  self.main = new_main
  log.trace("Root.change_main_branch(): main branch has been changed")
end

---Check if a branch exists or, not. `true` if it does `false`, otherwise.
---@param name string Label of the `Branch` that needs to be seached for.
---@return boolean
function Root:branch_exists(name)
  assert(name and type(name) == "string", "name needs to be a string and not nil.")
  return not not self.branches[name]
end

---Get the main `Branch` instance. This is not a copy but a reference.
---@return Branch
function Root:get_main_branch() return self.branches[self.main] end

---Generate a random branch name using current time (in milliseconds).
---@return string
local function date_name() return "branch_" .. os.date("%s") end

---Dummy function that always returns `true`.
---@return true
local function return_true() return true end

---@param on_collision fun(): boolean
---@param create_name fun(): string
function Root:stash_branch(on_collision, create_name)
  create_name = if_nil(create_name, date_name)
  on_collision = if_nil(on_collision, return_true)
  assert(type(create_name) == "function", "create_name must be a fun(): string")
  assert(type(on_collision) == "function", "will_wipe must be a fun(): boolean")

  local new_name = create_name()
  assert(type(new_name) == "string", "create_name should return string")
  local wipe = on_collision()
  assert(type(wipe) == "boolean", "on_collision should return boolean")
  log.trace("Root.stash_branch(): main branch has been stashed")

  if self.branches[new_name] and not wipe then return end
  self.stashed = self.main
  self:new_branch(new_name, true)
end

function Root:restore_branch()
  if not self.stashed then return end
  if self.branches[self.stashed] then self:change_main_branch(self.stashed) end
  self.stashed = nil
  log.trace("Root.restore_branch(): stashed branch has been restored")
end

function Root:alternate_branch()
  if not self.previous or not self.branches[self.previous] then return end
  self:change_main_branch(self.previous)
  log.trace("Root.alternate_branch(): main branch is now previous branch")
end

function Root:delete_main_branch()
  local names = vim.tbl_keys(self.branches)
  if #names == 1 then
    log.warn("Root.delete_branch(): tried deleting last branch " .. self.main)
    return
  end

  for index, name in ipairs(names) do
    if name == self.main then
      table.remove(names, index)
      self:change_main_branch(names[1]) -- changes self.main
      self:insert_history(self.branches[name])
      if self.previous == name then self.previous = nil end
      if self.stashed == name then self.stashed = nil end
      self.branches[name] = nil
      return
    end
  end
end

function Root:delete_branch(name)
  if not self:branch_exists(name) then
    log.warn("Root.delete_branch(): tried deleting a branch " .. name .. " that does not exist")
    return
  end
  if self.main == name then
    self:delete_main_branch()
    return
  end
  if self.previous == name then self.previous = nil end
  if self.stashed == name then self.stashed = nil end
  self:insert_history(self.branches[name])
  self.branches[name] = nil
end

function Root:insert_history(branch, force)
  local branch_type = type(branch)
  assert(branch_type == "table" and branch._NAME == CLASS.BRANCH, "branch: Branch cannot be nil")
  if self.disable_history and not force then return end
  table.insert(self.history, 1, branch)
  if #self.history > self.maximum_history then table.remove(self.history, #self.history) end
  log.trace("Root.insert_history(): branch " .. branch.name .. " has been recorded into history")
end

function Root:rename_branch(branch, new_name)
  local branch_type = type(branch)
  assert(
    branch_type == "string" or (branch_type == "table" and branch._NAME == CLASS.BRANCH),
    "branch: branch needs to be Branch|string"
  )
  local name = type(branch) == "string" and branch or branch.name
  if self:branch_exists(new_name) then return end
  local old_branch = self.branches[name]

  local main = self:get_main_branch().name == name
  local stashed = self.stashed == name
  local previous = self.previous == name

  old_branch.name = new_name
  self.branches[name] = nil
  self.branches[new_name] = old_branch

  self.main = main and new_name or self.main
  self.stashed = stashed and new_name or self.stashed
  self.previous = previous and new_name or self.previous
end

return Root
