local colors = require("colors").sections.spaces
local icons = require("icons")
local icon_map = require("helpers.icon_map")

local created_spaces = {}

local function add_windows(space, space_name)
  sbar.exec("aerospace list-windows --format %{app-name} --workspace " .. space_name, function(windows)
    local icon_line = ""
    for app in windows:gmatch "[^\r\n]+" do
      local lookup = icon_map[app]
      local icon = ((lookup == nil) and icon_map["Default"] or lookup)
      icon_line = icon_line .. " " .. icon
    end

    sbar.animate("tanh", 20, function()
      space:set {
        label = {
          string = icon_line == "" and "—" or icon_line,
          padding_right = icon_line == "" and 8 or 12,
        },
      }
    end)
  end)
end

local function update_spaces()
  sbar.exec("aerospace list-workspaces --all", function(spaces)
    local pending = {}
    local non_empty = {}
    for space_name in spaces:gmatch "[^\r\n]+" do
      table.insert(pending, space_name)
    end
    local checked = 0
    local changed = false
    for _, space_name in ipairs(pending) do
      sbar.exec("aerospace list-windows --workspace " .. space_name, function(windows)
        checked = checked + 1
        if windows and windows:match("%S") then
          table.insert(non_empty, space_name)
        end
        if checked == #pending then
          table.sort(non_empty)
          -- Remove any items not in non_empty
          local keep = {}
          for _, name in ipairs(non_empty) do keep[name] = true end
          for k, v in pairs(created_spaces) do
            if not keep[k] then v:remove() created_spaces[k] = nil changed = true end
          end
          -- Add missing items in order
          for _, space_name in ipairs(non_empty) do
            if not created_spaces[space_name] then
              local space = sbar.add("item", "space." .. space_name, {
                icon = {
                  string = space_name,
                  color = colors.icon.color,
                  highlight_color = colors.icon.highlight,
                  padding_left = 8,
                },
                label = {
                  font = "sketchybar-app-font:Regular:14.0",
                  string = "",
                  color = colors.label.color,
                  highlight_color = colors.label.highlight,
                  y_offset = -1,
                },
                click_script = "aerospace workspace " .. space_name,
                padding_left = space_name == "1" and 0 or 4,
              })
              created_spaces[space_name] = space
              add_windows(space, space_name)
              space:subscribe("aerospace_workspace_change", function(env)
                local selected = env.FOCUSED_WORKSPACE == space_name
                space:set {
                  icon = { highlight = selected },
                  label = { highlight = selected },
                }
                if selected then
                  sbar.animate("tanh", 3, function()
                    space:set {
                      background = {
                        shadow = {
                          distance = 0,
                        },
                      },
                      y_offset = -3,
                      padding_left = 8,
                      padding_right = 0,
                    }
                    space:set {
                      background = {
                        shadow = {
                          distance = 4,
                        },
                      },
                      y_offset = 0,
                      padding_left = 4,
                      padding_right = 4,
                    }
                  end)
                end
              end)
              space:subscribe("space_windows_change", function()
                add_windows(space, space_name)
              end)
              space:subscribe("mouse.clicked", function()
                sbar.animate("tanh", 8, function()
                  space:set {
                    background = {
                      shadow = {
                        distance = 0,
                      },
                    },
                    y_offset = -4,
                    padding_left = 8,
                    padding_right = 0,
                  }
                  space:set {
                    background = {
                      shadow = {
                        distance = 4,
                      },
                    },
                    y_offset = 0,
                    padding_left = 4,
                    padding_right = 4,
                  }
                end)
              end)
              changed = true
            end
          end
          if changed then
            sbar.hotload(true)
          end
        end
      end)
    end
  end)
end

update_spaces()

-- Subscribe globally to workspace and window changes
sbar.subscribe({"aerospace_workspace_change", "space_windows_change"}, function()
  update_spaces()
end)

-- local spaces_indicator = sbar.add("item", {
--   icon = {
--     padding_left = 8,
--     padding_right = 9,
--     string = icons.switch.on,
--     color = colors.indicator,
--   },
--   label = {
--     width = 0,
--     padding_left = 0,
--     padding_right = 8,
--   },
--   padding_right = 8,
-- })

-- spaces_indicator:subscribe("swap_menus_and_spaces", function()
--   local currently_on = spaces_indicator:query().icon.value == icons.switch.on
--   spaces_indicator:set {
--     icon = currently_on and icons.switch.off or icons.switch.on,
--   }
-- end)

-- spaces_indicator:subscribe("mouse.clicked", function()
--   sbar.animate("tanh", 8, function()
--     spaces_indicator:set {
--       background = {
--         shadow = {
--           distance = 0,
--         },
--       },
--       y_offset = -4,
--       padding_left = 8,
--       padding_right = 4,
--     }
--     spaces_indicator:set {
--       background = {
--         shadow = {
--           distance = 4,
--         },
--       },
--       y_offset = 0,
--       padding_left = 4,
--       padding_right = 8,
--     }
--   end)

  -- sbar.trigger("swap_menus_and_spaces")
-- end)
