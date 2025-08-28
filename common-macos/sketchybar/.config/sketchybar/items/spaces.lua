-- filepath: /Users/oliversteiner/.config/sketchybar/items/spaces.lua
-- Require necessary modules
local constants = require("constants")
local settings = require("config.settings")

-- Table to store sketchybar items for each workspace
local spaces = {}

-- Watcher item for handling swap events (menu/spaces)
local swapWatcher = sbar.add("item", {
  drawing = false,
  updates = true,
})

-- Watcher item for handling current workspace changes
local currentWorkspaceWatcher = sbar.add("item", {
  drawing = false,
  updates = true,
})

-- Configuration for each workspace, including icon and name
-- Modify this file with Visual Studio Code - at least vim does have problems with the icons
-- copy "Icons" from the nerd fonts cheat sheet and replace icon and name accordingly below
-- https://www.nerdfonts.com/cheat-sheet
local spaceConfigs <const> = {
  ["1"] = { icon = "󱞁", name = "Notes" },
  ["2"] = { icon = "", name = "Terminal" },
  ["3"] = { icon = "󰖟", name = "Browser" },
  ["4"] = { icon = "", name = "AltBrowser" },
  ["5"] = { icon = "", name = "Remote" },
  ["6"] = { icon = "", name = "Planner" },
  ["7"] = { icon = "󰊻", name = "Chat" },
  ["8"] = { icon = "", name = "Mail" },
  ["9"] = { icon = "", name = "Music" },
  ["10"] = { icon = "󰌾", name = "Secrets" },
  ["t"] = { icon = "", name = "Meeting" },
}

-- Function to select and highlight the current workspace item
local function selectCurrentWorkspace(focusedWorkspaceName)
  for sid, item in pairs(spaces) do
    if item ~= nil then
      local isSelected = sid == constants.items.SPACES .. "." .. focusedWorkspaceName
      item:set({
        icon = { color = isSelected and settings.colors.bg1 or settings.colors.white },
        label = { color = isSelected and settings.colors.bg1 or settings.colors.white },
        background = { color = isSelected and settings.colors.white or settings.colors.bg1 },
      })
    end
  end

  sbar.trigger(constants.events.UPDATE_WINDOWS)
end

-- Function to find the current workspace and then select it
local function findAndSelectCurrentWorkspace()
  sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(focusedWorkspaceOutput)
    local focusedWorkspaceName = focusedWorkspaceOutput:match("[^\r\n]+")
    selectCurrentWorkspace(focusedWorkspaceName)
  end)
end

-- Function to add a sketchybar item for a given workspace
local function addWorkspaceItem(workspaceName)
  local spaceName = constants.items.SPACES .. "." .. workspaceName
  local spaceConfig = spaceConfigs[workspaceName]

  spaces[spaceName] = sbar.add("item", spaceName, {
    label = {
      width = 0,
      padding_left = 0,
      string = spaceConfig.name,
    },
    icon = {
      string = spaceConfig.icon or settings.icons.apps["default"],
      color = settings.colors.white,
    },
    background = {
      color = settings.colors.bg1,
    },
    click_script = "aerospace workspace " .. workspaceName,
  })

  spaces[spaceName]:subscribe("mouse.entered", function(env)
    sbar.animate("tanh", 30, function()
      spaces[spaceName]:set({ label = { width = "dynamic" } })
    end)
  end)

  spaces[spaceName]:subscribe("mouse.exited", function(env)
    sbar.animate("tanh", 30, function()
      spaces[spaceName]:set({ label = { width = 0 } })
    end)
  end)

  sbar.add("item", spaceName .. ".padding", {
    width = settings.dimens.padding.label
  })
end

-- Function to create all workspace items based on aerospace workspaces
local function createWorkspaces()
  sbar.exec(constants.aerospace.LIST_ALL_WORKSPACES, function(workspacesOutput)
    for workspaceName in workspacesOutput:gmatch("[^\r\n]+") do
      addWorkspaceItem(workspaceName)
    end

    findAndSelectCurrentWorkspace()
  end)
end

-- Subscribe swapWatcher to the SWAP_MENU_AND_SPACES event
swapWatcher:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
  local isShowingSpaces = env.isShowingMenu == "off" and true or false
  sbar.set("/" .. constants.items.SPACES .. "\\..*/", { drawing = isShowingSpaces })
end)

-- Subscribe currentWorkspaceWatcher to the AEROSPACE_WORKSPACE_CHANGED event
currentWorkspaceWatcher:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
  selectCurrentWorkspace(env.FOCUSED_WORKSPACE)
  sbar.trigger(constants.events.UPDATE_WINDOWS)
end)

-- Initial creation of workspace items when the script loads
createWorkspaces()
