-------------------------------------------------------------------------------
---------------------------------- NAMESPACE ----------------------------------
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local L = ns.locale

-------------------------------------------------------------------------------
--------------------------------- CREATESLIDER --------------------------------
-------------------------------------------------------------------------------

local function Custom_CreateSlider(info, parent)
    local function format(v)
        if info.percentage then return FormatPercentage(v, true) end
        return string.format('%.2f', v)
    end

    parent:CreateTemplate(ADDON_NAME .. 'SliderMenuOptionTemplate')
        :AddInitializer(function(frame)
            local value = info.value()
            frame.Label:SetText(info.text)
            frame.Value:SetText(format(value))
            frame.Slider:SetMinMaxValues(info.min, info.max)
            frame.Slider:SetMinMaxValues(info.min, info.max)
            frame.Slider:SetValueStep(info.step)
            frame.Slider:SetAccessorFunction(function() return value end)
            frame.Slider:SetMutatorFunction(function(v)
                frame.Value:SetText(format(v))
                info.func(v)
            end)
            frame.Slider:UpdateVisibleState()
        end)
end

-------------------------------------------------------------------------------
---------------------------- WORLD MAP BUTTON MIXIN ---------------------------
-------------------------------------------------------------------------------

local WorldMapOptionsButtonMixin = {}
_G[ADDON_NAME .. 'WorldMapOptionsButtonMixin'] = WorldMapOptionsButtonMixin

-- Helper functions
local function IsGroupChecked(data) return data.group:GetDisplay(data.mapid) end
local function SetGroupChecked(data)
    data.group:SetDisplay(not IsGroupChecked(data), data.mapid)
end

local function GetOpt(option) return ns:GetOpt(option) end
local function SetOpt(option) ns:SetOpt(option, not ns:GetOpt(option)) end

local function GetGroupText(group, isAchievement) -- to assemble the Menu button text
    local iconLink = type(group.icon) == 'number' and
                         ns.GetIconLink(group.icon, 12, 1, 0) .. ' ' or
                         ns.GetIconLink(group.icon, 16)
    local status = ''

    if isAchievement then
        local _, _, _, completed, _, _, _, _, _, _, _, _, earnedByMe =
            GetAchievementInfo(group.achievement)
        status = ' ' .. (earnedByMe and ns.GetIconLink('check_gn') or
                     (completed and ns.GetIconLink('check_bl') or ''))
    end
    return iconLink .. ' ' .. ns.RenderLinks(group.label, true) .. status
end
-- Helper functions end

function WorldMapOptionsButtonMixin:OnLoad()
    self:SetupMenu(function(dropdown, root)
        local map = ns.maps[self:GetParent():GetMapID()]
        if not map then return end

        local current_group_type = nil
        local ach_menu = nil
        local achievements_menu_added = false

        for _, group in ipairs(map.groups) do
            -- Add a separator each time the group type changes
            if current_group_type and current_group_type ~= group.type then
                root:CreateDivider()
            end
            current_group_type = group.type

            if group:IsEnabled() and group:HasEnabledNodes(map) then
                if group.type == ns.group_types.ACHIEVEMENT then
                    if not achievements_menu_added then
                        ach_menu = root:CreateButton(
                            ns.GetIconLink(236671, 12, 1, 0) .. '  ' ..
                                ACHIEVEMENTS)
                        achievements_menu_added = true
                    end

                    if ach_menu ~= nil then
                        local ach_menu_button =
                            ach_menu:CreateCheckbox(GetGroupText(group, true),
                                IsGroupChecked, SetGroupChecked, {
                                    mapid = map.id,
                                    group = group
                                })
                        self:AddGroupOptions(group, ach_menu_button)
                    end
                else
                    local group_menu_button =
                        root:CreateCheckbox(GetGroupText(group), IsGroupChecked,
                            SetGroupChecked, {mapid = map.id, group = group})

                    -- Submenu for group options
                    self:AddGroupOptions(group, group_menu_button)
                end
            end
        end

        root:CreateDivider()

        local menu_reward_types = root:CreateButton(L['options_reward_types'])
        for _, type in ipairs({
            'manuscript', 'mount', 'pet', 'recipe', 'toy', 'transmog',
            'all_transmog'
        }) do
            menu_reward_types:CreateCheckbox(
                L['options_' .. type .. '_rewards'], GetOpt, SetOpt,
                'show_' .. type .. '_rewards')
        end

        root:CreateCheckbox(L['options_show_completed_nodes'], GetOpt, SetOpt,
            'show_completed_nodes')
        root:CreateCheckbox(L['options_toggle_hide_done_rare'], GetOpt, SetOpt,
            'hide_done_rares')
        root:CreateCheckbox(L['options_toggle_use_char_achieves'], GetOpt,
            SetOpt, 'use_char_achieves')

        root:CreateButton(L['options_open_settings_panel'], function()
            HideUIPanel(WorldMapFrame)
            Settings.OpenToCategory('HandyNotes')
            LibStub('AceConfigDialog-3.0'):SelectGroup('HandyNotes', 'plugins',
                ADDON_NAME, 'ZonesTab', 'Zone_' .. map.id)
        end)
    end)
end

function WorldMapOptionsButtonMixin:OnMouseDown(button)
    self.Icon:SetPoint('TOPLEFT', 8, -8)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function WorldMapOptionsButtonMixin:OnMouseUp()
    self.Icon:SetPoint('TOPLEFT', self, 'TOPLEFT', 6, -6)
end

function WorldMapOptionsButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip_SetTitle(GameTooltip, ns.plugin_name)
    GameTooltip_AddNormalLine(GameTooltip, L['map_button_text'])
    GameTooltip:Show()
end

function WorldMapOptionsButtonMixin:Refresh()
    local enabled = ns:GetOpt('show_worldmap_button')
    local map = ns.maps[self:GetParent():GetMapID() or 0]
    if enabled and map and map:HasEnabledGroups() then
        self:Show()
    else
        self:Hide()
    end
end

function WorldMapOptionsButtonMixin:AddGroupOptions(group, parent)
    local map = ns.maps[self:GetParent():GetMapID()]

    parent:CreateTemplate(ADDON_NAME .. 'TextMenuOptionTemplate')
        :AddInitializer(function(frame)
            frame.Text:SetText(ns.RenderLinks(group.desc))
        end)

    parent:CreateDivider()

    Custom_CreateSlider({
        text = L['options_opacity'],
        min = 0,
        max = 1,
        step = 0.01,
        value = function() return group:GetAlpha(map.id) end,
        percentage = true,
        func = function(v) group:SetAlpha(v, map.id) end
    }, parent)

    Custom_CreateSlider({
        text = L['options_scale'],
        min = 0.3,
        max = 3,
        step = 0.05,
        value = function() return group:GetScale(map.id) end,
        func = function(v) group:SetScale(v, map.id) end
    }, parent)
end

function WorldMapOptionsButtonMixin:InitializeDropDown(level)
    local map = ns.maps[self:GetParent():GetMapID()]

    if level == 1 then
        local current_group_type = nil
        local achievements_menu_added = false
        for i, group in ipairs(map.groups) do

            -- Add a separator each time the group type changes
            if current_group_type ~= nil and current_group_type ~= group.type then
                LibDD:UIDropDownMenu_AddSeparator()
            end
            current_group_type = group.type

            if group:IsEnabled() and group:HasEnabledNodes(map) then
                if group.type == ns.group_types.ACHIEVEMENT and
                    not achievements_menu_added then
                    LibDD:UIDropDownMenu_AddButton({
                        text = ns.GetIconLink(236671, 12, 1, 0) .. '  ' ..
                            ACHIEVEMENTS,
                        isNotRadio = true,
                        notCheckable = true,
                        keepShownOnClick = true,
                        hasArrow = true,
                        value = 'achievements'
                    })
                    achievements_menu_added = true
                elseif group.type ~= ns.group_types.ACHIEVEMENT then
                    self:AddGroupButton(group, 1)
                end
            end
        end

        LibDD:UIDropDownMenu_AddSeparator()
        LibDD:UIDropDownMenu_AddButton({
            text = L['options_reward_types'],
            isNotRadio = true,
            notCheckable = true,
            keepShownOnClick = true,
            hasArrow = true,
            value = 'rewards'
        })
        LibDD:UIDropDownMenu_AddButton({
            text = L['options_show_completed_nodes'],
            isNotRadio = true,
            keepShownOnClick = true,
            checked = ns:GetOpt('show_completed_nodes'),
            func = function(button, option)
                ns:SetOpt('show_completed_nodes', button.checked)
            end
        })
        LibDD:UIDropDownMenu_AddButton({
            text = L['options_toggle_hide_done_rare'],
            isNotRadio = true,
            keepShownOnClick = true,
            checked = ns:GetOpt('hide_done_rares'),
            func = function(button, option)
                ns:SetOpt('hide_done_rares', button.checked)
            end
        })
        LibDD:UIDropDownMenu_AddButton({
            text = L['options_toggle_use_char_achieves'],
            isNotRadio = true,
            keepShownOnClick = true,
            checked = ns:GetOpt('use_char_achieves'),
            func = function(button, option)
                ns:SetOpt('use_char_achieves', button.checked)
            end
        })

        LibDD:UIDropDownMenu_AddSeparator()
        LibDD:UIDropDownMenu_AddButton({
            text = L['options_open_settings_panel'],
            isNotRadio = true,
            notCheckable = true,
            disabled = not map.settings,
            func = function(button, option)
                HideUIPanel(WorldMapFrame)
                Settings.OpenToCategory('HandyNotes')
                LibStub('AceConfigDialog-3.0'):SelectGroup('HandyNotes',
                    'plugins', ADDON_NAME, 'ZonesTab', 'Zone_' .. map.id)
            end
        })
    elseif level == 2 then
        if L_UIDROPDOWNMENU_MENU_VALUE == 'achievements' then
            if not ns:GetOpt('show_achievements_rewards') then
                LibDD:UIDropDownMenu_AddButton({
                    text = 'Achievement Reward Tracking is off, therefore most Nodes will be hidden!\n',
                    isNotRadio = true,
                    notCheckable = true,
                    notClickable = true,
                    keepShownOnClick = true,
                    -- hasArrow = true,
                    -- value = 'rewards'
                },level)
                LibDD:UIDropDownMenu_AddSeparator(level)
            end
            for i, group in ipairs(map.groups) do
                if group.type == ns.group_types.ACHIEVEMENT and
                    group:IsEnabled() and group:HasEnabledNodes(map) then
                    self:AddGroupButton(group, 2)
                end
            end
        elseif L_UIDROPDOWNMENU_MENU_VALUE == 'rewards' then
            for i, type in ipairs({
                'achievements', 'manuscript', 'skinning', 'mount', 'pet', 'recipe', 'toy', 'transmog',
                'all_transmog'
            }) do
                LibDD:UIDropDownMenu_AddButton({
                    text = L['options_' .. type .. '_rewards'],
                    isNotRadio = true,
                    keepShownOnClick = true,
                    checked = ns:GetOpt('show_' .. type .. '_rewards'),
                    func = function(button, option)
                        ns:SetOpt('show_' .. type .. '_rewards', button.checked)
                    end
                }, 2)
            end
        else
            -- add opacity/scale menu for non-achievements
            self:AddGroupOptions(L_UIDROPDOWNMENU_MENU_VALUE, 2)
        end
    elseif level == 3 then
        -- add opacity/scale menu for achievements
        self:AddGroupOptions(L_UIDROPDOWNMENU_MENU_VALUE, 3)
    end
end
