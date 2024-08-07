---@class TrackPickersViewsHooks
---@field on_open function This will be called before the picker window is opened.
---@field on_close function(buffer: number, picker: Picker) This will be called right after the picker window is closed.
---@field on_choose function(buffer: number, picker: Picker) Will be called after the choice is made and the picker os closed.
---@field on_serial function(entry: table, picker: Picker)|nil|false Map a callback numerical keys with respect to entry index.

---@class TrackPickersViewsIcons
---@field separator string Separator between columns in the views picker.
---@field missing string Indicator icon for representing a missing/deleted file.
---@field accessible string Indicator icon for representing a file that allows reading.
---@field inaccessible string Indicator icon for representing a file that does not allow reading from it.
---@field focused string Indicator icon for representing a file that is currently being edited on.
---@field listed string Indicator icon for representing if a file is already open.
---@field unlisted string Indicator icon for representing if a file is not open.
---@field file string Default file icon. This will be visible when `disable_devicons` is `true`.
---@field directory string Directory icon. This will be visible when a directory mark is added.

---Other config opts that are not documented here can be found at |telecope.nvim| help page.
---@class TrackPickersViews
---@field hooks TrackPickersViewsHooks Callbacks related to the views picker.
---@field save_on_close boolean Save state when the views telescope buffer is closed.
---@field switch_directory boolean Change directory and refresh picker if a marked directory is in state.
---@field icons TrackPickersViewsIcons File-indicators, state-indicators, separators and default icons.

---Other config opts that are not documented here can be found at |telecope.nvim| help page.
---@class TrackPickersBranches
---@field hooks TrackPickersBranchesHooks Callbacks related to the views picker.
---@field icons TrackPickersBranchesIcons File-indicators, state-indicators, separators and default icons.
---@field save_on_close boolean Save state when the branches telescope buffer is closed.

---@class TrackPickersBranchesHooks
---@field on_open function This will be called before the picker window is opened.
---@field on_close function(buffer: number, picker: Picker) This will be called right after the picker window is closed.
---@field on_choose function(buffer: number, picker: Picker) Will be called after the choice is made and the picker os closed.
---@field on_serial function(entry: table, picker: Picker)|nil|false Map a callback numerical keys with respect to entry index.

---@class TrackPickersBranchesIcons

---@class TrackPickers
---@field views TrackPickersViews Configuration opts relating to the `views` telescope picker.
---@field branches TrackPickersBranches Configuration opts relating to the `branches` telescope picker.

---@class TrackLog
---@field level "error"|"warn"|"info"|"trace"|"debug"|"off" Log level. The higher the level is, lesser the STDOUT messages will be shown.
---@field plugin string Name of the plugin.

---@class TrackPad
---@field config table
---@field root_path? string Function that must return the path to the current working directory.
---@field save_on_close boolean Save state when the views pad buffer is closed.

---@class TrackOpts
---@field save_path string JSON file where the current state will be saved.
---@field root_path string|true Default `root_path`. Setting to to true fetches automatically.
---@field branch_name string|true Default `branch_name` to open based on `root_path`.
---@field disable_history boolean Change state of all branch histories.
---@field maximum_history number Change the maximum number of marks to be stored in all branch history tables.
---@field pickers TrackPickers Sub-configuration for telescope pickers.
---@field log TrackLog Sub-configuration for logging and debugging.
---@field pad TrackPad Sub-configuration for pad UI.
---@field exclude string[] Patterns that won't be allowed to be added into the marks list.

---@class Root
---@field path string Path to root.
---@field label? string Small description/title about the root.
---@field branches Branch[] Branch map. Key is the same as `Branch.label` and value is a `Branch` instance.
---@field main string Master branch. This is similar to the `main` branch in GIT.
---@field stashed? string Flag variable that will be set if a branch has been stashed.
---@field previous? string Flag variable that will be set if the `main` branch has an alternate branch.
---@field disable_history? boolean Deleting branches will not store said branches in the `history` table.
---@field maximum_history? number Maximum number of branches that are allowed to be in `history` table.
---@field history Branch[] Deleted/Uneeded branch are sent here. This acts as a recycle bin for branches.
---@field _NAME string Type.

---@class RootFields
---@field path string Path to root.
---@field label? string Small description/title about the root.
---@field branches? Branch[] Branch map. Key is the same as `Branch.name` and value is a `Branch` instance.
---@field main? string Master branch. This is similar to the `main` branch in GIT.
---@field stashed? string Flag variable that will be set if a branch has been stashed.
---@field previous? string Flag variable that will be set if the `main` branch has an alternate branch.
---@field disable_history? boolean Deleting branches will not store said branches in the `history` table.
---@field maximum_history? number Maximum number of branches that are allowed to be in `history` table.
---@field history Branch[] Deleted/Uneeded branch are sent here. This acts as a recycle bin for branches.

---@class Branch
---@field name string Name of the branch. Similar to setting a GIT branch name.
---@field disable_history? boolean Deleting marks will not store said marks in the `history` table.
---@field maximum_history? number Maximum number of marks that are allowed to be in `history` table.
---@field history Mark[] Deleted/Uneeded marks are sent here. This acts as a recycle bin for marks.
---@field marks table<string, Mark> Mark map. Key is the same as `Mark.uri`. Therefore, no duplicates.
---@field views string[] Paths of newly added marks are inserted into this list. This is to maintain order.
---@field _NAME string Type.

---@class BranchFields
---@field name string Name of the branch. Similar to setting a GIT branch name.
---@field disable_history? boolean Deleting marks will not store marks in the `history` table.
---@field maximum_history? number Maximum number of marks that are allowed to be in `history` table.
---@field history Mark[] Deleted/Uneeded marks are sent here. This acts as a recycle bin for marks.

---@alias MarkType string

---A class that represents a mark. A mark is a path inside (most of the time)
---your current working directory. It serves as a project-scoped file-bookmark.
---@class Mark
---@field path string Path to mark.
---@field absolute string Absolute path to mark.
---@field type? string Type of mark.
---@field _NAME string Type.

---@class MarkFields
---@field uri string Path to mark.
---@field type? MarkType Optional type for the mark.

---@alias Core table

---@alias TrackHooks table
