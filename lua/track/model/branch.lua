---@diagnostic disable: undefined-field, inject-field
---A virtual mark-map. Allows one to create different versions of marks that
---is better suited to a part of a project that you might be working on.
---
---For instance:
---Working at part `A` of a project will require you to frequent
---`A1`, `A2` and `A3` files and working part `B` would require `B1`, `B2`, `B3`.
---Normally, without branches one may put all project files (`A1-3` and `B1-3`) in
---the mark-list or, remove all `A1-3` files and add `B1-3` files and vice-versa.
---This adds overhead.
---Now, with branches you just need to **stash** the current branch which contains A1-3
---(say) and add `B1-3` to the new branch. (Yes, this is just like GIT.)
local Branch = {}
Branch.__index = Branch
setmetatable(Branch, {
  __call = function(class, ...)
    local self = setmetatable({}, class)
    self:_new(...)
    self._callize_views(self)
    self._callize_marks(self)
    return self
  end,
})

local Mark = require("track.model.mark")
local log = require("track.dev.log")
local if_nil = vim.F.if_nil
local CLASS = require("track.dev.enum").CLASS

---Create a new `Branch` object.
---@param opts BranchFields Available branch attributes/fields.
---@return Branch
function Branch:_new(opts)
  local types = type(opts)
  assert(types ~= "table" or types ~= "string", "expected: fields: string|table found: " .. types)
  ---@diagnostic disable-next-line: missing-fields
  if types == "string" then opts = { name = opts } end
  assert(opts.name and type(opts.name) == "string", "fields.name: string cannot be nil")

  self.name = opts.name
  self.marks = {}
  self.views = {}
  self.disable_history = if_nil(opts.disable_history, true)
  self.maximum_history = if_nil(opts.maximum_history, 10)
  self.history = if_nil(opts.history, {})
  ---@diagnostic disable-next-line: missing-return
  self._NAME = CLASS.BRANCH
end

-- Metatable Setters {{{
---@private
---Helper for re-registering the `__call` metatable to `Branch.views` field.
function Branch:_callize_views()
  setmetatable(self.views, {
    ---@return Mark[]?
    __call = function(views, _)
      local view_marks = {}
      for _, view in ipairs(views) do
        table.insert(view_marks, self.marks[view])
      end
      return view_marks
    end,
  })
end

---@private
---Helper for re-registering the `__call` metatable to `Branch.marks` field.
function Branch:_callize_marks()
  setmetatable(self.marks, {
    __call = function(marks, action)
      if action == "string" then return vim.tbl_keys(marks) end
      return vim.tbl_values(marks)
    end,
  })
end
-- }}}

---Add a mark into the `Branch`.
---@param mark Mark|string `Mark` or, the path that will be turned into a `Mark`.
---@return Mark
function Branch:add_mark(mark)
  if type(mark) == "table" and mark._NAME == CLASS.MARK then
    local absolute = mark:absolute()
    self.marks[absolute] = mark
    if #vim.tbl_keys(self.marks) ~= #self.views then table.insert(self.views, absolute) end
    log.trace("Branch.add_mark(): new mark " .. absolute .. " has been added")
    return self.marks[absolute]
  end
  -- if it does not exist then create it
  return self:add_mark(Mark({ uri = mark }))
end

---Remove a mark from the Branch. Returns the removed mark (if available).
---@param mark Mark|string `Mark` or, the path that will be removed from the `Branch.marks` table.
---@return Mark
function Branch:remove_mark(mark)
  local rm_mark
  if type(mark) == "table" and mark._NAME == CLASS.MARK then
    rm_mark = self.marks[mark:absolute()]
  else
    local temp_mark = Mark({ uri = mark })
    rm_mark = self.marks[temp_mark:absolute()]
  end
  local absolute = rm_mark:absolute()

  self.marks[absolute] = nil
  -- removing a mark will also remove its path from the views table
  -- how do I make this faster O(N) is not good.
  -- thinking more about this... can the marklist go beyond 100 :thonk:
  self.views = vim.tbl_filter(function(item) return item ~= absolute end, self.views)
  -- self.views is being overwritten which means any metatable will also be overwritten
  -- we need to re-register the __call metatable so that external parties can call
  -- Branch.view() again.
  self:_callize_views()
  -- record history: removed marks will be inserted into the self.history table (by your will)
  self:insert_history(rm_mark)
  log.trace("Branch.remove_mark(): mark " .. absolute .. " has been removed")
  return rm_mark
end

---Reset the `Branch`. All marks will be purged.
function Branch:clear()
  for _, mark in pairs(self.marks) do
    self:insert_history(mark)
  end
  self.marks = {}
  self.views = {}
  -- re-attach __call.
  self:_callize_views()
  self:_callize_marks()
  log.trace("Branch.clear(): Branch.marks and Branch.views has been emptied")
end

---Insert mark into the history list.
---@param mark Mark The `Mark` object that needs to be inserted into the history list.
---@param force? boolean overrides `Branch.disable_history`.
function Branch:insert_history(mark, force)
  local mark_type = type(mark)
  assert(mark_type == "table" and mark._NAME == CLASS.MARK, "mark: Mark cannot be nil.")
  if self.disable_history and not force then return end
  table.insert(self.history, 1, mark)
  if #self.history > self.maximum_history then table.remove(self.history, #self.history) end
  log.trace("Branch.insert_history(): mark " .. mark:absolute() .. " has been recorded into history")
end

---Swap marks.
---@param a number
---@param b number
function Branch:swap_marks(a, b)
  if not self.views[a] or not self.views[b] then return end
  local temp = self.views[a]
  self.views[a] = self.views[b]
  self.views[b] = temp
end

---Change a mark's path.
---@param mark Mark
---@param uri string
function Branch:change_mark_uri(mark, uri)
  assert(type(mark) == "table" and mark._NAME == CLASS.MARK, "mark: restricted type")
  local abs = mark:absolute()
  local new_mark = Mark({ uri = uri })
  local new_abs = new_mark:absolute()
  for index, view in ipairs(self.views) do
    if view == abs then
      self.views[index] = new_abs
      self.marks[view] = nil
      self.marks[new_abs] = new_mark
      return new_mark
    end
  end
end

---Check if the `Branch` has any marks.
---@return boolean
function Branch:empty() return vim.tbl_isempty(self.marks) end

return Branch
