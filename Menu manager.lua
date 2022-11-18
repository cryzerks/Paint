-----------------------------------------------------
-- Callback system
-----------------------------------------------------

--- @region: callback system
local callbacks = {}
local data_calls = {}
local data_delay_calls = {}

--- @info: Initialize callbacks.
--- @param: event_type: string
--- @return: void
function callbacks.init(event_type)
    if (type(event_type) ~= "string") then
        error("Invalid type of callback")
        return
    end

    data_calls[event_type] = {}
    data_calls[event_type].list = {}

    data_calls[event_type].func = function(...)
        for key, value in pairs(data_calls[event_type].list) do
            value.func(...)
        end
    end

    cheat.push_callback(event_type, data_calls[event_type].func)
end

--- @param: event_type: string
--- @param: callback: function
--- @return: void
function callbacks.add(event_type, callback)
    if (callback == nil) then
        error("Undefined callbacked variable")
        return
    end

    if (type(callback) ~= "function") then
        error("Invalid type of callbacked variable")
        return
    end

    if (not data_calls[event_type]) then
        callbacks.init(event_type)
    end

    table.insert(data_calls[event_type].list, {func = callback})
end

--- @info: Removes a callback that was previously set using 'callbacks.add'
--- @param: event_type: string
--- @param: callback: function
--- @return: void
function callbacks.remove(event_type, callback)
    if (data_calls[event_type] == nil) then
        error("Undefined callback")
        return
    end

    if (type(callback) ~= "function") then
        error("Invalid type of variable to remove")
        return
    end

    for key, value in pairs(data_calls[event_type].list) do
        if (value.func == callback) then
            table.remove(data_calls[event_type].list, key)

            return
        end
    end
end
--- @endregion

-----------------------------------------------------
-- Menu helpers
-----------------------------------------------------


--- @region: menu helpers
local menu = {}
local menu_callbacks = {}

--- @param: item_type: string
--- @param: name: string
--- @param: item: menu_item
--- @param: func: function
--- @return: void
function menu.set_callback(item_type, name, item, func)
    callbacks.add("on_paint", function()
        if (menu_callbacks[name] == nil) then
            menu_callbacks[name] = {itmes = {}, data = {}, clicked_value = 0}
        end

        local self = menu_callbacks[name]

        if (item_type == "checkbox" or item_type == "hotkey") then
            self.clicked_value = item:get() and math.min(3, self.clicked_value + 1) or math.max(0, self.clicked_value - 1)

            if (self.clicked_value == 2) then
                func(item:get())
            end
        elseif (item_type == "combo") then
            local item_value = item:get()

            if (self.clicked_value and self.clicked_value == item_value) then
                goto skip
            end

            func(item_value)

            self.clicked_value = item_value
            ::skip::
        elseif (item_type == "button") then
            if (item:get()) then
                func(item:get())
            end
        end
    end)
end
--- @endregion

--- @region: menu_item
--- @class: menu_item_c
--- @field: public: element_type: string
--- @field: public: name: string
local menu_item_c = {}
local menu_item_mt = { __index = menu_item_c }

local groups_en = {
    ["First"] = 1,
    ["Second"] = 2
}

--- @info: Create a new menu_item_c.
--- @param: element_type: string
--- @param: element: function
--- @param: name: string
--- @param: group: string
--- @vararg: any
--- @return: menu_item_c
function menu_item_c.new(element_type, element, name, group, to_save, condition, ...)
    assert(element, 4, "Cannot create menu item because: %s", "attempt to call a nil value (local 'element')")

    local reference

    if (type(element) == "function") then
        local do_ui_new = element(name, ...)

        reference = do_ui_new
    else
        reference = element
    end

    return setmetatable({
        element_type = element_type,
        reference = reference,

        group = group,

        name = name,

        to_save = to_save,
        condition = condition,
    }, menu_item_mt)
end

--- @param: func: function
--- @return: void
function menu_item_c:set_callback(func)
    return menu.set_callback(self.element_type, ("%s_%s"):format(self.name, self.element_type), self.reference, func)
end

--- @vararg: any
--- @return: void
function menu_item_c:set(...)
    local args = {...}

    self.reference:set(table.unpack(args))
end

--- @param: group: string
--- @return: void
function menu_item_c:setup_group()
    self.reference:set_group(groups_en[self.group] or 1)
end

--- @vararg: string
--- @return: void
function menu_item_c:set_items(...)
    local args = {...}

    if (type(args[1]) == "table") then
        args = args[1]
    end

    self.reference:set_items(args)
end

--- @return: table
function menu_item_c:get_items()
    return self.reference:get_items()
end

--- @return: any
function menu_item_c:get()
    return self.reference:get()
end

--- @param: state: boolean
--- @return: any
function menu_item_c:set_visible(state)
    self.reference:set_visible(state)
end
--- @endregion

-----------------------------------------------------
-- Menu manager
-----------------------------------------------------

--- @region: menu_manager
--- @class: menu_manager_c
--- @field: public: tab: string
--- @field: public: name: string
--- @field: public: to_save: boolean
--- @field: public: condition: function
--- @field: public: reference: menu item
local menu_manager_c = {}
local menu_manager_mt = { __index = menu_manager_c }

local menu_manager_current_tab = ui.add_combobox("Current Tab:", {"Loading..."})
menu_manager_current_tab:set_group(1)

local menu_manager_tabs = {}
local menu_manager_items = {}
local current_tab = "string"

--- @info: Create a new menu_manager_c.
--- @param: tab: string
--- @param: name: string
--- @param: group: string
--- @param: to_save: boolean: optional
--- @param: condition: function: optional
--- @return: menu_manager_c
function menu_manager_c.new(tab, group, name, to_save, condition)
    return setmetatable({
        tab = tab == nil and "Global" or tab,
        name = name,
        group = group,

        to_save = to_save == nil and true or to_save,
        condition = condition == nil and function()
            return true
        end or condition,
    }, menu_manager_mt)
end

--- @param: tab: string
--- @param: name: string
--- @return: menu_item_c
function menu_manager_c.reference(tab, group, name)
    return menu_manager_items[tab][group][name].reference
end

--- @vararg: string
--- @return: menu_item_c
function menu_manager_c:combo(...)
    local args = {...}

    if (type(args[1]) == "table") then
        args = args[1]
    end

    return self:_create_item("combo", ui.add_combobox, args)
end

--- @return: menu_item_c
function menu_manager_c:checkbox()
    local item = self:_create_item("checkbox", ui.add_checkbox)

    return item
end

--- @return: menu_item_c
function menu_manager_c:hotkey()
    local item = self:_create_item("hotkey", ui.add_hotkey)

    return item
end

--- @return: menu_item_c
function menu_manager_c:label()
    self.to_save = false

    return self:_create_item("label", ui.add_label)
end

--- @param: callback: function
--- @return: menu_item_c
function menu_manager_c:button(callback)
    self.to_save = false

    local item = self:_create_item("button", ui.add_button)

    if (callback ~= nil) then
        callbacks.add("on_paint", function()
            if (item:get()) then
                callback()
            end
        end)
    end

    return item
end

--- @param: s_type: string
--- @param: min: number
--- @param: max: number
--- @return: menu_item_c
function menu_manager_c:slider(min, max, default_value, s_type)
    if (s_type == nil) then
        s_type = "int"
    end

    if (type(min) ~= "number") then
        cheat.notify("Slider min value must be a number.")
        return
    end

    if (type(max) ~= "number") then
        cheat.notify("Slider max value must be a number.")
        return
    end

    if (min > max) then
        cheat.notify("Slider min value must be below the max value.")
        return
    end

    local item = self:_create_item("slider", ui["add_slider"..s_type], min, max)

    if (default_value ~= nil) then
        item.reference:set(default_value)
    end

    return item
end

--- @return: menu_item_c
function menu_manager_c:color_picker()
    return self:_create_item("color_picker", ui.add_colorpicker)
end

--- @return: void
function menu_manager_c.update_visible()
    for tab_name, tab_value in pairs(menu_manager_items) do
        for item_name, item_value in pairs(tab_value) do
            local tabs = menu_manager_current_tab:get_items()
            local condition = tabs[menu_manager_current_tab:get() + 1] == tab_name and item_value.condition()

            item_value.reference:set_visible(condition)
            item_value.reference:setup_group()
        end
    end
end

--- @param: element_type: string
--- @param: element: function
--- @vararg: any
--- @return: menu_item_c
function menu_manager_c:_create_item(element_type, element, ...)
    assert(type(self.name) == "string" and self.name ~= "", 3, "Cannot create menu item: name must be a non-empty string.")

    local item = menu_item_c.new(element_type, element, self.name, self.group, self.to_save, self.condition, ...)

    if (menu_manager_items[self.tab] == nil) then
        menu_manager_items[self.tab] = {}

        table.insert(menu_manager_tabs, self.tab)
        menu_manager_current_tab:set_items(menu_manager_tabs)
    end

    if (menu_manager_items[self.tab][self.name] ~= nil) then
        return
    end

    menu_manager_items[self.tab][self.name] = {
        reference = item,
        to_save = self.to_save,
        element_type = element_type,
        condition = self.condition
    }

    local function update_value()
        menu_manager_c.update_visible()
    end

    item:set_callback(update_value)
    update_value()

    menu_manager_c.update_visible()

    return item
end

menu.set_callback("combo", "menu_manager_current_tab", menu_manager_current_tab, function()
    menu_manager_c.update_visible()
end)
--- @endregion