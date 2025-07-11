--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Chili Pro Console",
    desc      = "v0.016 Chili Chat Pro Console.",
    author    = "CarRepairer",
    date      = "2014-04-20",
    license   = "GNU GPL, v2 or later",
    layer     = 50,
    experimental = false,
    enabled   = true,
  }
end

include("keysym.lua")
include("Widgets/COFCTools/ExportUtilities.lua")

local missionMode = Spring.GetModOptions().singleplayercampaignbattleid

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- message rules - widget stuff
--[[
each message definition can have:
	- either 1 format
	- either name + output, output containing pairs of { name = '', format = '' }
all the names are used when displaying the options

format syntax:
- #x : switch to color 'x' where 'x' can be:
	- a : ally (option)
	- e : everyone (option)
	- o : other (option)
	- s : spec (option)
	- h : highlight (option)
	- p : color of the player who sent message (dynamic)
- $var : gets replaced by msg['var'] ; interesting vars:
	- playername
	- argument	for messages, this is only the message part; for labels, this is the caption
	- msgtype	type of message as identified by parseMessage()
	- priority	as received by widget:AddConsoleLine()
	- text		full message, as received by widget:AddConsoleLine()

--]]
local MESSAGE_RULES = {
	player_to_allies = {
		name = "Player to allies message",
		output = {
			{
				name = "Only bracket in player's color, message in 'ally' color",
				format = '#p<#e$playername#p> #a$argument'
			},
			{
				name = "Playername in his color, message in 'ally' color",
				format = '#p<$playername> #a$argument',
				default = true
			},
			{
				name = "Playername and message in player's color",
				format = '#p<$playername> $argument'
			},
		}
	},
	player_to_player_received = { format = '#p$playername #e{text}: $argument' },
	player_to_player_sent = { format = 'you -> #p$playername#e: $argument' }, -- NOTE: #p will be color of destination player!
	player_to_specs = { format = '#p<$playername> #s$argument' },
	player_to_everyone = { format = '#p<$playername> #e$argument' },
	player_to_player_spec = {format = '#p$playername#e $playername2 #e$argument'},

	spec_to_specs = { format = '#s[$playername] $argument' },
	spec_to_allies = { format = '#s[$playername] $argument' }, -- TODO is there a reason to differentiate spec_to_specs and spec_to_allies??
	spec_to_everyone = { format = '#s[$playername] #e$argument' },

	-- shameful copy-paste -- TODO remove this duplication
	replay_spec_to_specs = { format = '#s[$playername (replay)] $argument' },
	replay_spec_to_allies = { format = '#s[$playername (replay)] $argument' }, -- TODO is there a reason to differentiate spec_to_specs and spec_to_allies??
	replay_spec_to_everyone = { format = '#s[$playername (replay)] #e$argument' },

	label = {
		name = "Labels",
		output = {
			{
				name = "Show label text in white",
				format = '#p$playername#e added label: $argument',
				default = true
			},
			{
				name = "Show label text in 'ally' color",
				format = '#p$playername#e added label: #a$argument',
			},
			{
				name = "Show label text in the player's color",
				format = '#p$playername#e added label: #p$argument'
			},
		}
	},
	point = { format = '#p$playername#e added point.' },
	autohost = { format = '#o> $argument', noplayername = true },
	other = { format = '#o$text' }, -- no pattern... will match anything else
	game_message = { format = '#o$text' }, -- no pattern...
	game_priority_message = { format = '#e$text' }, -- no pattern...
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local SOUNDS = {
	ally = "sounds/talk.wav",
	label = "sounds/talk.wav",
	lobby = "sounds/beep4_decrackled.wav",
	highlight = "sounds/mentioned.wav",
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local HIGHLIGHT_SURROUND_SEQUENCE_1 = ' >>> '
local HIGHLIGHT_SURROUND_SEQUENCE_2 = ' <<<'
local DEDUPE_SUFFIX = 'x '

local MIN_HEIGHT = 50
local MAX_HEIGHT = 2160
local MIN_WIDTH = 300
local MAX_STORED_MESSAGES = 300

local inputsize = 25
local CONCURRENT_SOUND_GAP = 0.1 -- seconds

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

WG.enteringText = false
WG.chat = WG.chat or {}

local screen0
local myName -- my console name
local myAllyTeamId

local control_id = 0
local stack_console, stack_chat, stack_backchat
local window_console, window_chat
local fadeTracker = {}
local scrollpanel_chat, scrollpanel_console, scrollpanel_backchat
local inputspace
local backlogButton
local backlogButtonImage
local color2incolor

local echo = Spring.Echo

local incolor_dup
local incolor_highlight
local incolors = {} -- incolors indexed by playername + special #a/#e/#o/#s/#h colors based on config

local consoleMessages = {} -- message buffer
local chatMessages = {} -- message buffer
local highlightPattern -- currently based on player name -- TODO add configurable list of highlight patterns

local firstEnter = true --used to activate ally-chat at game start. To run once
local recentSoundTime = false -- Limit the rate at which sounds are played.

local lastMsgChat, lastMsgBackChat, lastMsgConsole
local textPerms = {}

------------------------------------------------------------
-- options

options_path = "Settings/HUD Panels/Chat"

local dedupe_path = options_path .. '/De-Duplication'
local hilite_path = options_path .. '/Highlighting'
local filter_path = options_path .. '/Filtering'
local color_path = options_path .. '/Color Setup'
local deathMessages = true

options_order = {
	
	'lblGeneral',
	
	'enableConsole',
	'death_messages',
	--'mousewheel',
	'defaultAllyChat',
	'defaultBacklogEnabled',
	'filter_commanderselection',
	'mousewheelBacklog',
	'enableSwap',
	'backlogHideNotChat',
	'backlogShowWithChatEntry',
	'backlogArrowOnRight',
	'changeFont',
	'enableChatBackground',
	'hideChat',
	'toggleBacklog',
	'text_height_chat',
	'text_height_console',
	'backchatOpacity',
	'autohide_text_time',
	'max_lines',
	'clickable_points',
	
	'lblMisc',
	
	'color_chat_background','color_console_background',
	'color_chat', 'color_ally', 'color_other', 'color_spec',
	'color_usernames',
	
	'hideSpec', 'hideAlly', 'hidePoint', 'hideLabel', 'hideLog',
	'error_opengl_source',
	'filter_luaHandleCheckStack',
	
	--'pointButtonOpacity',
	
	'highlight_all_private', 'highlight_filter_allies', 'highlight_filter_enemies', 'highlight_filter_specs', 'highlight_filter_other',
	'highlight_surround', 'highlight_sound', 'send_lobby_updates', 'sound_for_lobby', 'color_highlight', 'color_from_lobby',
	
	--'highlighted_text_height',
	
	'dedupe_messages', 'dedupe_points','color_dup',
}

local function onOptionsChanged()
	RemakeConsole()
end

local showingBackchat = false
local showingNothing = false
local wantHidden = false

local function SwapBacklog()
	if showingBackchat then
		if not showingNothing then
			window_chat:RemoveChild(scrollpanel_backchat)
		end
		if wantHidden then
			showingBackchat = false
			showingNothing = true
			return
		else
			window_chat:AddChild(scrollpanel_chat)
			backlogButtonImage.file = 'LuaUI/Images/arrowhead.png'
			backlogButtonImage:Invalidate()
		end
	else
		if not showingNothing then
			window_chat:RemoveChild(scrollpanel_chat)
		end
		window_chat:AddChild(scrollpanel_backchat)
		backlogButtonImage.file = 'LuaUI/Images/arrowhead_flipped.png'
		backlogButtonImage:Invalidate()
	end
	showingBackchat = not showingBackchat
	showingNothing = false
end

local function SetHidden(hidden)
	if hidden == wantHidden then
		return
	end
	wantHidden = hidden
	
	if wantHidden then
		if showingBackchat then
			window_chat:RemoveChild(scrollpanel_backchat)
		else
			window_chat:RemoveChild(scrollpanel_chat)
		end
		showingNothing = true
	else
		showingBackchat = true
		SwapBacklog()
	end
end

options = {
	
	--lblFilter = {name='Filtering', type='label', advanced = false},
	--lblPointButtons = {name='Point Buttons', type='label', advanced = true},
	lblAutohide = {name='Auto Hiding', type='label'},
	--lblHilite = {name='Highlighting', type='label'},
	--lblDedupe = {name='De-Duplication', type='label'},
	lblGeneral = {name='General Settings', type='label'},
	lblMisc = {name='Misc. Settings', type='label'},
	
	error_opengl_source = {
		name = "Filter out \'Error: OpenGL: source\' error",
		type = 'bool',
		value = true,
		desc = "This filter out \'Error: OpenGL: source\' error message from ingame chat, which happen specifically in Spring 91 with Intel Mesa driver."
		.."\nTips: the spam will be written in infolog.txt, if the file get unmanageably large try set it to Read-Only to prevent write.",
		path = filter_path ,
		advanced = true,
	},
	filter_luaHandleCheckStack = {
		name = "Filter out \'LuaHandle::CheckStack\' error",
		type = 'bool',
		value = true,
		desc = "This filters out a message that appears usesless, and started being spammed in 105.1.1-2511.",
		path = filter_path ,
		advanced = true,
	},
	
	enableConsole = {
		name = "Enable the debug console",
		type = 'bool',
		value = false,
		advanced = true,
		OnChange = function(self)
			if window_console then
				if self.value then
					screen0:AddChild(window_console)
				else
					screen0:RemoveChild(window_console)
				end
			end
		end
	},
	
	text_height_chat = {
		name = 'Chat Text Size',
		type = 'number',
		value = 14,
		min = 8, max = 30, step = 1,
		OnChange = onOptionsChanged,
	},
	text_height_console = {
		name = 'Log Text Size',
		type = 'number',
		value = 14,
		min = 8, max = 30, step = 1,
		OnChange = onOptionsChanged,
	},
	
	highlighted_text_height = {
		name = 'Highlighted Text Size',
		type = 'number',
		value = 16,
		min = 8, max = 30, step = 1,
		OnChange = onOptionsChanged,
	},
	clickable_points = {
		name = "Clickable points and labels",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	--[[
	pointButtonOpacity = {
		name = "Point button opacity",
		type = 'number',
		value = 0.25,
		min = 0, max = 1, step = 0.05,
		advanced = true,
	},
	--]]
	-- TODO work in progress
	dedupe_messages = {
		name = "Dedupe messages",
		type = 'bool',
		value = true,
		OnChange = onOptionsChanged,
		advanced = true,
		noHotkey = true,
		path = dedupe_path,
	},
	dedupe_points = {
		name = "Dedupe points and labels",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = onOptionsChanged,
		advanced = true,
		path = dedupe_path,
	},
	highlight_all_private = {
		name = "Highlight all private messages",
		type = 'bool',
		value = true,
		noHotkey = true,
		advanced = true,
		path = hilite_path,
	},
	highlight_filter_allies = {
		name = "Check allies messages for highlight",
		type = 'bool',
		value = true,
		noHotkey = true,
		advanced = true,
		path = hilite_path,
	},
	highlight_filter_enemies = {
		name = "Check enemy messages for highlight",
		type = 'bool',
		value = true,
		noHotkey = true,
		advanced = true,
		path = hilite_path,
	},
	highlight_filter_specs = {
		name = "Check spec messages for highlight",
		type = 'bool',
		value = true,
		noHotkey = true,
		advanced = true,
		path = hilite_path,
	},
	highlight_filter_other = {
		name = "Check other messages for highlight",
		type = 'bool',
		value = false,
		noHotkey = true,
		advanced = true,
		path = hilite_path,
	},
	filter_commanderselection = {
		name = "Filter out commander selection messages",
		type = 'bool',
		value = false,
		desc = "This filters out commander messages.",
		path = filter_path ,
		advanced = false,
	},
--[[
	highlight_filter = {
		name = 'Highlight filter',
		type = 'list',
		OnChange = onOptionsChanged, -- NO NEED
		value = 'allies',
		items = {
			{ key = 'disabled', name = "Disabled" },
			{ key = 'allies', name = "Highlight only allies messages" },
			{ key = 'all', name = "Highlight all messages" },
		},
		advanced = true,
	},
--]]
	
	highlight_surround = {
		name = "Surround highlighted messages",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = onOptionsChanged,
		advanced = true,
		path = hilite_path,
	},
	highlight_sound = {
		name = "Sound for highlighted messages",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = onOptionsChanged,
		advanced = true,
		path = hilite_path,
	},
	send_lobby_updates = {
		name = "Display lobby chat and updates",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = onOptionsChanged,
		path = hilite_path,
	},
	sound_for_lobby = {
		name = "Play sound for lobby updates",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = onOptionsChanged,
		path = hilite_path,
	},
	hideSpec = {
		name = "Hide Spectator Chat",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = false,
		path = filter_path,
	},
	hideAlly = {
		name = "Hide Ally Chat",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
		path = filter_path,
	},
	hidePoint = {
		name = "Hide Points",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
		path = filter_path,
	},
	hideLabel = {
		name = "Hide Labels",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
		path = filter_path,
	},
	hideLog = {
		name = "Hide Engine Logging Messages",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
		path = filter_path,
	},
	max_lines = {
		name = 'Maximum Lines (20-100)',
		type = 'number',
		value = 60,
		min = 20, max = 100, step = 1,
		OnChange = onOptionsChanged,
	},
	
	color_chat = {
		name = 'Everyone chat text',
		type = 'colors',
		value = { 1, 1, 1, 1 },
		OnChange = onOptionsChanged,
		path = color_path,
	},
	color_ally = {
		name = 'Ally text',
		type = 'colors',
		value = { 0.2, 1, 0.2, 1 },
		OnChange = onOptionsChanged,
		path = color_path,
	},
	color_other = {
		name = 'Other text',
		type = 'colors',
		value = { 0.6, 0.6, 0.6, 1 },
		OnChange = onOptionsChanged,
		path = color_path,
	},
	color_spec = {
		name = 'Spectator text',
		type = 'colors',
		value = { 0.8, 0.8, 0.8, 1 },
		OnChange = onOptionsChanged,
		path = color_path,
	},
	color_usernames = {
		name = "Color usernames in messages",
		type = 'bool',
		value = true,
		OnChange = onOptionsChanged,
		advanced = true,
		path = color_path,
	},
	color_dup = {
		name = 'Duplicate message mark',
		type = 'colors',
		value = { 1, 0.2, 0.2, 1 },
		OnChange = onOptionsChanged,
		path = dedupe_path,
	},
	color_highlight = {
		name = 'Highlight mark',
		type = 'colors',
		value = { 1, 1, 0.2, 1 },
		OnChange = onOptionsChanged,
		path = hilite_path,
	},
	color_from_lobby = {
		name = 'Lobby notification color',
		type = 'colors',
		value = { 1, 0.2, 1, 1 },
		OnChange = onOptionsChanged,
		path = hilite_path,
	},
	color_chat_background = {
		name = "Chat Background color",
		type = "colors",
		value = { 0, 0, 0, 0},
		OnChange = function(self)
			scrollpanel_chat.backgroundColor = self.value
			scrollpanel_chat.borderColor = self.value
			scrollpanel_chat:Invalidate()
		end,
		path = color_path,
	},
	color_console_background = {
		name = "Console Background color",
		type = "colors",
		value = { 0, 0, 0, 0},
		OnChange = function(self)
			-- [[
			scrollpanel_console.backgroundColor = self.value
			scrollpanel_console.borderColor = self.value
			scrollpanel_console:Invalidate()
			--]]
			window_console.backgroundColor = self.value
			window_console.color = self.value
			window_console:Invalidate()
		end,
		path = color_path,
	},
	--[[
	mousewheel = {
		name = "Scroll with mousewheel",
		type = 'bool',
		value = false,
		OnChange = function(self) scrollpanel_console.ignoreMouseWheel = not self.value; end,
	},
	--]]
	defaultAllyChat = {
		name = "Default Chat Mode",
		type = 'radioButton',
		desc = "Sets default chat mode to allies at game start",
		value = 'auto',
		items = {
			{key = 'on',   name = 'Ally/Spectator Chat', desc = "Always start the game with ally chat or spectator chat enabled."},
			{key = 'auto', name = 'Context Dependant',   desc = "Start the game with ally chat enabled if you have any allies. Always start the game with spectator chat enabled."},
			{key = 'off',  name = 'All Chat',            desc = "Start the game with ally and spectator chat disabled."},
		},
		OnChange = CheckHide,
		noHotkey = true,
	},
	defaultBacklogEnabled = {
		name = "Enable backlog at start",
		desc = "Starts with the backlog chat enabled.",
		type = 'bool',
		value = false,
		noHotkey = true,
	},
	toggleBacklog = {
		name = "Toggle backlog",
		desc = "The toggle backlog button is here to let you hotkey this action.",
		type = 'button',
	},
	mousewheelBacklog = {
		name = "Mousewheel Backlog",
		desc = "Scroll the backlog chat with the mousewheel.",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = function(self)
			scrollpanel_backchat.ignoreMouseWheel = not options.mousewheelBacklog.value
			scrollpanel_backchat:Invalidate()
		end,
	},
	enableSwap = {
		name = "Show backlog arrow",
		desc = "Enable the button to swap between chat and backlog chat.",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = function(self)
			if self.value then
				window_chat:AddChild(backlogButton)
				if options.enableChatBackground.value then
					window_chat:RemoveChild(inputspace)
				end
				inputspace = WG.Chili.ScrollPanel:New{
					x = (options.backlogArrowOnRight.value and 0) or inputsize,
					right = ((not options.backlogArrowOnRight.value) and 0) or inputsize,
					bottom = 0,
					height = inputsize,
					noFont = true,
					backgroundColor = {1,1,1,1},
					borderColor = {0,0,0,1},
					--backgroundColor = {1,1,1,1},
				}
				if options.enableChatBackground.value then
					window_chat:AddChild(inputspace)
				end
			else
				window_chat:RemoveChild(backlogButton)
				if options.enableChatBackground.value then
					window_chat:RemoveChild(inputspace)
				end
				inputspace = WG.Chili.ScrollPanel:New{
					x = 0,
					bottom = 0,
					right = 0,
					height = inputsize,
					noFont = true,
					backgroundColor = {1,1,1,1},
					borderColor = {0,0,0,1},
					--backgroundColor = {1,1,1,1},
				}
				if options.enableChatBackground.value then
					window_chat:AddChild(inputspace)
				end
			end
			window_chat:Invalidate()
		end,
	},
	backlogHideNotChat = {
		name = "Hide arrow when not chatting",
		desc = "Enable to hide the backlog arrow when not entering chat.",
		type = 'bool',
		value = false,
		OnChange = function(self)
			if self.value then
				if backlogButton and backlogButton.parent then
					backlogButton:SetVisibility(WG.enteringText)
				end
			else
				if backlogButton and backlogButton.parent then
					backlogButton:SetVisibility(true)
				end
			end
		end
	},
	backlogShowWithChatEntry = {
		name = "Auto-toggle backlog",
		desc = "Enable to have the backlog enabled when entering text and disabled when not entering text.",
		type = 'bool',
		value = false,
	},
	backlogArrowOnRight = {
		name = "Backlong Arrow On Right",
		desc = "Puts the backlong arrow on the right. It appear on the left if disabled..",
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = function(self)
			if window_chat and window_chat:GetChildByName("backlogButton") then
				backlogButton._relativeBounds.left = ((not self.value) and 0) or nil
				backlogButton._relativeBounds.right = (self.value and 0) or nil
				backlogButton:UpdateClientArea()
				
				window_chat:Invalidate()
			end
		end,
	},
	changeFont = {
		name = "Change message entering font.",
		desc = "With this enabled the text-entering font will be changed to match the chat. May cause Spring to competely lock up intermittently on load. Requires reload to update.",
		type = 'bool',
		value = false,
		advanced = true,
		noHotkey = true,
	},
	enableChatBackground = {
		name = "Enable chat background.",
		desc = "Enables a background for the text-entering box.",
		type = 'bool',
		value = false,
		noHotkey = true,
		advanced = true,
		OnChange = function(self)
			if self.value then
				window_chat:AddChild(inputspace)
			else
				window_chat:RemoveChild(inputspace)
			end
			scrollpanel_console:Invalidate()
		end,
	},
	hideChat = {
		name = "Hide when not chatting",
		desc = "Hide the chat completely when not entering chat.",
		type = 'bool',
		value = false,
		OnChange = function(self)
			SetHidden(self.value)
		end,
	},
	backchatOpacity = {
		name = "Backlog Border Opacity",
		type = 'number',
		value = 0.5,
		min = 0, max = 1, step = 0.05,
		OnChange = function(self)
			scrollpanel_backchat.borderColor = {0,0,0,self.value}
			scrollpanel_backchat:Invalidate()
		end,
	},
	autohide_text_time = {
		name = "Text decay time",
		type = 'number',
		value = 20,
		min = 10, max = 60, step = 5,
		--OnChange = onOptionsChanged,
	},
	death_messages = {
		name = "Add silly death messages on player resign",
		type = 'bool',
		value = true,
		OnChange = function(self)
			deathMessages = self.value
		end,
	},
	
}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--functions

local function SetInputFontSize(size)
	if options.changeFont.value then
		Spring.SetConfigInt("FontSize", size, true) --3rd param true is "this game only"
		Spring.SendCommands('font ' .. WG.Chili.EditBox.font.font)
	end
end

--------------------------------------------------------------------------------
-- TODO : should these pattern/escape functions be moved to some shared file/library?

local function nocase(s)
  return string.gsub(s, "%a", function (c)
		return string.format("[%s%s]", string.lower(c), string.upper(c))
	  end
  )
end

local function escapePatternMatchChars(s)
  return string.gsub(s, "(%W)", "%%%1")
end

local function caseInsensitivePattern(s)
  return nocase(escapePatternMatchChars(s))
end

-- local widget only
function getMessageRuleOptionName(msgtype, suboption)
  return msgtype .. "_" .. suboption
end

local function GetPlayerColor(name)
	return incolors[name] or incolors['#s']
end


for msgtype,rule in pairs(MESSAGE_RULES) do
	if rule.output and rule.name then -- if definition has multiple output formats, make associated config option
		local option_name = getMessageRuleOptionName(msgtype, "output_format")
		options_order[#options_order + 1] = option_name
		local o = {
			name = "Format for " .. rule.name,
			type = 'list',
			OnChange = function (self)
				Spring.Echo('Selected: ' .. self.value)
				onOptionsChanged()
			end,
			value = '1', -- may be overriden
			items = {},
			advanced = true,
		}
		
		for i, output in ipairs(rule.output) do
			o.items[i] = { key = i, name = output.name }
			if output.default then
				o.value = i
			end
		end
		options[option_name] = o
    end
end

local function getOutputFormat(msgtype)
	local rule = MESSAGE_RULES[msgtype]
	if not rule then
		Spring.Echo("UNKNOWN MESSAGE TYPE: " .. msgtype or "NiL")
		return
	elseif rule.output then -- rule has multiple user-selectable output formats
		local option_name = getMessageRuleOptionName(msgtype, "output_format")
		local value = options[option_name].value
		return rule.output[value].format
	else -- rule has only 1 format defined
		return rule.format
	end
end

local function getSource(spec, allyTeamId)
	return (spec and 'spec')
		or ((Spring.GetMyTeamID() == allyTeamId) and 'ally')
		or 'enemy'
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function escape_lua_pattern(s)

	local matches =
	{
		["^"] = "%^";
		["$"] = "%$";
		["("] = "%(";
		[")"] = "%)";
		["%"] = "%%";
		["."] = "%.";
		["["] = "%[";
		["]"] = "%]";
		["*"] = "%*";
		["+"] = "%+";
		["-"] = "%-";
		["?"] = "%?";
		["\0"] = "%z";
	}

  
	return (s:gsub(".", matches))
end

local function PlaySound(id, condition)
	if recentSoundTime then
		return
	end
	if condition ~= nil and not condition then
		return
	end
	local file = SOUNDS[id]
	if file then
		Spring.PlaySoundFile(file, 1, 'ui')
		recentSoundTime = CONCURRENT_SOUND_GAP
	end
end

local rainbowTable

local function MakeTextRainbow(text)
	local colorIndex = math.random(1, #rainbowTable)
	local ret = ""
	for i = 3, #text do
		local c = text:sub(i, i)
		if c ~= ' ' then
			if ret then
				ret = ret .. rainbowTable[colorIndex]
			else
				ret = rainbowTable[colorIndex]
			end
		end
		colorIndex = colorIndex + 1
		ret = ret .. c
		if colorIndex > #rainbowTable then colorIndex = 1 end
	end
	ret = ret .. color2incolor({1,1,1,1})
	return ret
end

local function detectHighlight(msg)
	-- must handle case where we are spec and message comes from player
	
	if msg.msgtype == 'game_priority_message' then
		msg.highlight = true
		return
	end
	if msg.msgtype == 'player_to_player_received' then
		if options.highlight_all_private.value then
			msg.highlight = true
		end
		local fromName = Spring.GetPlayerInfo(msg.player.id, false)
		--Spring.Echo("Recieved a PM! Begin formatting for LuaUIMsgSend: From: " .. fromName)
		local packet = 'whisperto_' .. fromName .. "," .. msg.argument
		--Spring.Echo("Send: " .. packet)
		if not Spring.IsReplay() then
			Spring.SendLuaUIMsg(packet, 's')
		end
		return
	end
	if msg.msgtype == 'player_to_everyone' then
		local mod = msg.argument:sub(1,2)
		--Spring.Echo(msg.playername)
		if mod == '#r' then
			if textPerms[msg.playername] then
				msg.argument = MakeTextRainbow(msg.argument)
			else
				msg.argument = msg.argument:sub(3, #msg.argument)
			end
		elseif mod == '#i' then
			if textPerms[msg.playername] and textPerms[msg.playername] > 2 then
				msg.argument = msg.argument:sub(3, #msg.argument)
				msg.argument = color2incolor({255/255, 164/255, 46/255, 1}) .. msg.argument .. color2incolor({1,1,1,1})
				msg.highlight = true
			else
				msg.argument = msg.argument:sub(3, #msg.argument)
			end
			return
		elseif textPerms[msg.playername] and textPerms[msg.playername] == 2 then -- ghostfenix chat is purple
			msg.argument = color2incolor({27/255, 192/255, 254/255, 1}) ..msg.argument .. color2incolor({1,1,1,1})
		end
	end
	
--	Spring.Echo("msg.source = " .. (msg.source or 'NiL'))
	
	if msg.source == 'ally' and not options.highlight_filter_allies.value
	or msg.source == 'enemy' and not options.highlight_filter_enemies.value
	or msg.source == 'spec' and not options.highlight_filter_specs.value
	or msg.source == 'other' and not options.highlight_filter_other.value then
		return
	end

	if (msg.argument and msg.argument:find(highlightPattern)) then
		msg.highlight = true
	end
end

local function formatMessage(msg) -- formatting done here
	local format = getOutputFormat(msg.msgtype) or getOutputFormat("other")
	-- Find and colour any usernames in the message body
	if options.color_usernames.value then
		-- This could be slightly faster by caching the value for each format rule,
		-- but that's more effort elsewhere, risks cache bugs,
		-- this operation is much faster than the N regex replacements,
		-- and this code path isn't that hot to begin with (not many chat messages per second)
		local last_colour_code = format:match('.*(#%w)') or '#o'
		local message_colour = incolors[last_colour_code]

		-- Lua lacks \b, so we match with spaces instead and strip the added ones afterwards
		local formatted_arg = ' '..msg.argument..' '
		-- incolors contains the control codes #[aehos] and also each player's username
		-- we get all the usernames by iterating it and just ignoring the #[aehos] control codes
		for name, colour in pairs(incolors) do
			if name:sub(1,1) ~= '#' then
				local pattern = '([^%w_])(' .. name .. ')([^%w_])'
				local sub = '%1'..colour..'%2'..message_colour..'%3'
				formatted_arg, _ = formatted_arg:gsub(pattern, sub)
			end
		end
		msg.argument = formatted_arg:sub(2, -2)  -- strip added spaces
	end

	-- insert/sandwich colour string into text
	local formatted, _ = format:gsub('([#%$]%w+)', function(parameter) -- FIXME pattern too broad for 1-char color specifiers
			if parameter:sub(1,1) == '$' then
				return msg[parameter:sub(2,parameter:len())]
			elseif parameter == '#t' then
				if msg.playername2 then
					return GetPlayerColor(msg.playername2)
				else
					return incolors['#o']
				end
			elseif parameter == '#p' then
				if msg.playername and incolors[msg.playername] then
					return GetPlayerColor(msg.playername)
				else
					return incolors['#o'] -- player still at lobby, use grey text
				end
			else
				return incolors[parameter]
			end
		end)
	msg.formatted = formatted
	--]]
	msg.textFormatted = msg.text
	if msg.playername then
		local out = msg.text
		local playerName = escape_lua_pattern(msg.playername)
		out = out:gsub( '^<' .. playerName ..'> ', '' )
		out = out:gsub( '^%[' .. playerName ..'%] ', '' )
		msg.textFormatted = out
	end
	msg.source2 = msg.playername or ''
end

local function MessageIsChatInfo(msg)
	return string.find(msg.argument,'Speed set to') or
	string.find(msg.argument,'following') or
	string.find(msg.argument,'Connection attempted') or
	string.find(msg.argument,'exited') or
	string.find(msg.argument,'is no more') or
	string.find(msg.argument,'paused the game') or
	string.find(msg.argument,'Sync error for') or
	string.find(msg.argument,'Cheating is') or
	string.find(msg.argument,'GodModeAction') or
	string.find(msg.argument,'GlobalLosActionExecutor') or
	string.find(msg.argument,'Everything%-for%-free') or
	string.find(msg.argument,'resigned') or
	(string.find(msg.argument,'left the game') and string.find(msg.argument,'Player'))
	--string.find(msg.argument,'Team') --endgame comedic message. Engine message, loaded from gamedata/messages.lua (hopefully 'Team' with capital 'T' is not used anywhere else)
end

local function hideMessage(msg)
	return (msg.msgtype == "spec_to_everyone" and options.hideSpec.value) -- can only hide spec when playing
		or (msg.msgtype == "player_to_allies" and options.hideAlly.value)
		or (msg.msgtype == "point" and options.hidePoint.value)
		or (msg.msgtype == "label" and options.hideLabel.value)
		or (msg.msgtype == 'other' and options.hideLog.value and not MessageIsChatInfo(msg))
end

local function AddMessage(msg, target, remake)
	if hideMessage(msg) or (not WG.Chili) then
		return
	end
	
	local stack
	local fade
	local size
	local lastMsg
	local size
	if target == 'chat' then
		stack = stack_chat
		size = options.text_height_chat.value
		if not remake then
			fade = true
		end
		lastMsg = lastMsgChat
	elseif target == 'console' then
		stack = stack_console
		size = options.text_height_console.value
		lastMsg = lastMsgConsole
	elseif target == 'backchat' then
		size = options.text_height_chat.value
		stack = stack_backchat
		lastMsg = lastMsgBackChat
	end
	
	if not stack then
		-- stack_console may not yet be created.
		return
	end
	
	--if msg.highlight and options.highlighted_text_height.value
	
	-- TODO betterify this / make configurable
	local highlight_sequence1 = (msg.highlight and options.highlight_surround.value and (incolor_highlight .. HIGHLIGHT_SURROUND_SEQUENCE_1) or '')
	local highlight_sequence2 = (msg.highlight and options.highlight_surround.value and (incolor_highlight .. HIGHLIGHT_SURROUND_SEQUENCE_2) or '')
	local text = (msg.dup > 1 and (incolor_dup .. msg.dup .. DEDUPE_SUFFIX) or '') .. highlight_sequence1 .. msg.formatted .. highlight_sequence2

	if msg.dup > 1 and not remake then
		--local last = stack.children[#(stack.children)]
		
		if lastMsg then
			if lastMsg.SetText then
				lastMsg:SetText(text)
				-- UpdateClientArea() is not enough - last message keeps disappearing until new message is added
				lastMsg:Invalidate()
			end
		end
		return
	end
	
	local textbox = WG.Chili.TextBox:New{
		width = '100%',
		align = "left",
		valign = "ascender",
		lineSpacing = 0,
		padding = { 0, 0, 0, 0 },
		text = text,
		
		--[[
		autoHeight=true,
		autoObeyLineHeight=true,
		--]]
		objectOverrideFont = WG.GetSpecialFont(size, "proconsole", {
			outlineWidth = 2,
			outlineWeight = 10,
			outline = true,
		})
	}
	
	if options.clickable_points.value then
		local control = textbox
		if msg.point then --message is a marker, make obvious looking button
			local padding
			if target == 'chat' then
				padding = { 3,3,1,1 }
			else
				padding = { 1,1,1,1 }
			end
			textbox:SetPos( 35, 3, stack.width - 40 )
			textbox:Update()
			local tbheight = textbox.height -- not perfect
			tbheight = math.max( tbheight, 15 ) --hack
			--echo('tbheight', tbheight)
			control = WG.Chili.Panel:New{
				width = '100%',
				height = tbheight + 8,
				padding = padding,
				margin = {0,0,0,0},
				backgroundColor = {0,0,0,0},
				caption = '',
				children = {
					WG.Chili.Button:New{
						noFont = true,
						x=0;y=0;
						width = 30,
						height = 20,
						classname = "overlay_button_tiny",
						--backgroundColor = {1,1,1,options.pointButtonOpacity.value},
						padding = {2,2,2,2},
						children = {
							WG.Chili.Image:New {
								x=7;y=2;
								width = 14,
								height = 14,
								keepAspect = true,
								file = 'LuaUI/Images/Crystal_Clear_action_flag.png',
							}
						},
						OnClick = {function(self, x, y, mouse)
							local alt,ctrl, meta,shift = Spring.GetModKeyState()
							if (shift or ctrl or meta or alt) or ( mouse ~= 1 ) then return false end --skip modifier key since they indirectly meant player are using click to issue command (do not steal click)
							SetCameraTarget(msg.point.x, msg.point.y, msg.point.z, 1)
						end}
					},
					textbox,
				},
				
			}
		elseif target == 'chat' then
			-- Make a panel for each chat line because this removes the message jitter upon fade.
			textbox:SetPos( 3, 3, stack.width - 3 )
			textbox:Update()
			local tbheight = textbox.height + 2 -- not perfect
			--echo('tbheight', tbheight)
			control = WG.Chili.Panel:New{
				width = '100%',
				height = tbheight,
				padding = { 0,0,0,0 },
				backgroundColor = {0,0,0,0},
				caption = '',
				children = {
					textbox,
				},
			}
		elseif WG.alliedCursorsPos and msg.player and msg.player.id then --message is regular chat, make hidden button
			local cur = WG.alliedCursorsPos[msg.player.id]
			if cur then
				textbox.OnMouseDown = {function(self, x, y, mouse)
						local alt,ctrl, meta,shift = Spring.GetModKeyState()
						if ( shift or ctrl or meta or alt ) then return false end --skip all modifier key
						local click_on_text = x <= textbox.font:GetTextWidth(self.text); -- use self.text instead of text to include dedupe message prefix
						if (mouse == 1 and click_on_text) then
							SetCameraTarget(cur[1], 0,cur[2], 1) --go to where player is pointing at. NOTE: "cur" is table referenced to "WG.alliedCursorsPos" so its always updated with latest value
						end
				end}
				function textbox:HitTest(x, y)  -- copied this hack from chili bubbles
					return self
				end
			end
		end
		stack:AddChild(control, false)
		if fade then
			control.fade = 1
			fadeTracker[control_id] = control
			control_id = control_id + 1
		end
		--]]
	else
		stack:AddChild(textbox, false)
		if fade then
			textbox.fade = 1
			fadeTracker[control_id] = textbox
			control_id = control_id + 1
		end
	end
	
	if target == 'chat' then
		lastMsgChat = textbox
	elseif target == 'backchat' then
		lastMsgBackChat = textbox
	else
		lastMsgConsole = textbox
	end

	stack:UpdateClientArea()
end


local function setupColors()
	incolor_dup			= color2incolor(options.color_dup.value)
	incolor_highlight	= color2incolor(options.color_highlight.value)
	incolor_fromlobby	= color2incolor(options.color_from_lobby.value)
	incolors['#h']		= incolor_highlight
	incolors['#a'] 		= color2incolor(options.color_ally.value)
	incolors['#e'] 		= color2incolor(options.color_chat.value)
	incolors['#w']      = color2incolor({2/255, 209/255, 209/255, 1})
	incolors['#o'] 		= color2incolor(options.color_other.value)
	incolors['#s'] 		= color2incolor(options.color_spec.value)
	incolors['#p'] 		= '' -- gets replaced with a player-specific color later; here just not to crash
end



local function setupPlayers(playerID)
	if playerID then
		local name, active, spec, teamId, allyTeamId, _, _, _, _, ck = Spring.GetPlayerInfo(playerID, true)
		--lobby: grey chat, spec: white chat, player: color chat
		incolors[name] = (spec and incolors['#s']) or color2incolor(Spring.GetTeamColor(teamId))
		if ck.badges then -- look for fw badges
			if ck.badges:find("fw_dev") then
				textPerms[name] = 3
			elseif ck.badges:find("fw_fenix") then
				textPerms[name] = 2
			elseif ck.badges:find("fw_vet") and textPerms[name] == nil then -- maybe allow FW donators to color chat?
				textPerms[name] = 1
			end
		end
	else
		local allyList = Spring.GetAllyTeamList()
		for j = 1, #allyList do
			local allyTeam = allyList[j]
			local teamList = Spring.GetTeamList(allyTeam)
			for k = 1, #teamList do
				local teamID = teamList[k]
				local playerroster = Spring.GetPlayerList(teamID)
				for i = 1, #playerroster do
					local id = playerroster[i]
					local name, active, spec, teamId, allyTeamId, _, _, _, _, ck = Spring.GetPlayerInfo(id, true)
					--lobby: grey chat, spec: white chat, player: color chat
					--Spring.Echo(name .. ": " .. tostring(spec))
					incolors[name] = (spec and incolors['#s']) or color2incolor(Spring.GetTeamColor(teamId))
					if ck.badges then -- look for fw badges
						if ck.badges:find("fw_dev") then
							textPerms[name] = 3
							break
						elseif ck.badges:find("fw_fenix") then
							textPerms[name] = 2
							break
						elseif ck.badges:find("fw_vet") and textPerms[name] == nil then -- maybe allow FW donators to color chat?
							textPerms[name] = 1
							break
						end
					end
				end
			end
		end
	end
end

local function SetupAITeamColor() --Copied from gui_chili_chat2_1.lua
	-- register any AIs
	-- Copied from gui_chili_crudeplayerlist.lua
	local teamsSorted = Spring.GetTeamList()
	for i=1,#teamsSorted do
		local teamID = teamsSorted[i]
		if teamID ~= Spring.GetGaiaTeamID() then
			local isAI = select(4,Spring.GetTeamInfo(teamID, false))
			if isAI then
				local name = select(2,Spring.GetAIInfo(teamID))
				incolors[name] = color2incolor(Spring.GetTeamColor(teamID))
			end
		end --if teamID ~= Spring.GetGaiaTeamID()
	end --for each team
end

local function setupMyself()
	myName, _, _, _, myAllyTeamId = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false) -- or do it in the loop?
	highlightPattern = caseInsensitivePattern(myName)
end

local function setup()
	setupPlayers()
	setupMyself()
	setupColors()
	SetupAITeamColor()
end

local function removeToMaxLines()
	if stack_console then
		while #stack_console.children > options.max_lines.value do
			-- stack:RemoveChild(stack.children[1]) --disconnect children
			if stack_console.children[1] then
				stack_console.children[1]:Dispose() --dispose/disconnect children (safer)
			end
			--stack:UpdateLayout()
		end
	end
	while #stack_backchat.children > options.max_lines.value do
		-- stack:RemoveChild(stack.children[1]) --disconnect children
		if stack_backchat.children[1] then
			stack_backchat.children[1]:Dispose() --dispose/disconnect children (safer)
		end
		--stack:UpdateLayout()
	end
end


function RemakeConsole()
	setup()
	-- stack_console:ClearChildren() --disconnect from all children
	if stack_console then
		for i=1, #stack_console.children do
			stack_console.children[1]:Dispose() --dispose/disconnect all children (safer)
		end
	end
	
	for i=1, #stack_backchat.children do
		stack_backchat.children[1]:Dispose() --dispose/disconnect all children (safer)
	end
	
	-- FIXME : messages collection changing while iterating (if max_lines option has been shrinked)
	for i = 1, #chatMessages do
		local msg = chatMessages[i]
		--AddMessage(msg, 'chat', true, true )
		AddMessage(msg, 'backchat', true )
	end
	for i = 1, #consoleMessages do
		local msg = consoleMessages[i]
		AddMessage(msg, 'console', true )
	end
	removeToMaxLines()
	
end

local function ShowInputSpace()
	WG.enteringText = true
	inputspace.backgroundColor = {1,1,1,1}
	inputspace.borderColor = {0,0,0,1}
	inputspace:Invalidate()
	
	if options.backlogHideNotChat.value and backlogButton and backlogButton.parent then
		backlogButton:SetVisibility(true)
	end
end
local function HideInputSpace()
	WG.enteringText = false
	inputspace.backgroundColor = {0,0,0,0}
	inputspace.borderColor = {0,0,0,0}
	inputspace:Invalidate()
	
	if options.backlogHideNotChat.value and backlogButton and backlogButton.parent then
		backlogButton:SetVisibility(false)
	end
end

local function MakeMessageStack(margin)
	return WG.Chili.StackPanel:New{
		margin = { 0, 0, 0, 0 },
		padding = { 0, 0, 0, 0 },
		x = 0,
		y = 0,
		--width = '100%',
		right=5,
		height = 10,
		resizeItems = false,
		itemPadding  = { 1, 1, 1, 1 },
		itemMargin  = { margin, margin, margin, margin },
		autosize = true,
		preserveChildrenOrder = true,
		useRTT = false,
	}
end

local function MakeMessageWindow(name, enabled, ParentFunc)

	local x,y,bottom,width,height
	local screenWidth, screenHeight = Spring.GetViewGeometry()
	if name == "ProChat" then
		local integralWidth = math.max(350, math.min(450, screenWidth*screenHeight*0.0004))
		local integralHeight = math.min(screenHeight/4.5, 200*integralWidth/450)
		width = 450
		x = integralWidth
		height = integralHeight*0.84
		bottom = integralHeight*0.84
	else
		local resourceBarWidth = 430
		local maxWidth = math.min(screenWidth/2 - resourceBarWidth/2, screenWidth - 400 - resourceBarWidth)
		bottom = nil
		width  = 380 - 4	--screenWidth * 0.30	-- 380 is epic menu bar width
		height = screenHeight * 0.20
		x = screenWidth - width
		y = 50
		if maxWidth < width then
			y = 50 -- resource bar height
		end
	end
	
	if enabled and ParentFunc then
		ParentFunc()
	end
	
	return WG.Chili.Window:New{
		parent = (enabled and screen0) or nil,
		margin = { 0, 0, 0, 0 },
		padding = { 0, 0, 0, 0 },
		noFont = true,
		dockable = true,
		name = name,
		x = x,
		y = y,
		bottom = bottom,
		width  = width,
		height = height,
		draggable = false,
		resizable = false,
		tweakDraggable = true,
		tweakResizable = true,
		minimizable = false,
		parentWidgetName = widget:GetInfo().name, --for gui_chili_docking.lua (minimize function)
		minWidth = MIN_WIDTH,
		minHeight = MIN_HEIGHT,
		maxHeight = MAX_HEIGHT,
		color = { 0, 0, 0, 0 },
		OnMouseDown = {
			function(self) --//click on scroll bar shortcut to "Settings/HUD Panels/Chat/Console".
				local _,_, meta,_ = Spring.GetModKeyState()
				if not meta then return false end
				WG.crude.OpenPath(options_path)
				WG.crude.ShowMenu() --make epic Chili menu appear.
				return true
			end
		},
		OnParent = ParentFunc and {
			ParentFunc
		},
	}
end

local function SetBacklogShow(newShow)
	if newShow == showingBackchat then
		return
	end
	SwapBacklog()
end

options.toggleBacklog.OnChange = SwapBacklog

-----------------------------------------------------------------------
-- callins
-----------------------------------------------------------------------

local function CheckEnableAllyChat()
	if options.defaultAllyChat.value == "off" then
		return false
	elseif options.defaultAllyChat.value == "on" then
		return true
	end
	if Spring.GetSpectatingState() then
		return true
	end
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	if not myAllyTeamID then
		return true
	end
	local myTeamList = Spring.GetTeamList(myAllyTeamID)
	return (not myTeamList) or (#myTeamList > 1)
end

local keypadEnterPressed = false

function widget:KeyPress(key, modifier, isRepeat)
	if key == KEYSYMS.KP_ENTER then
		keypadEnterPressed = true
	end
	if (key == KEYSYMS.RETURN) or (key == KEYSYMS.KP_ENTER) then
		if firstEnter then
			if (not (modifier.Shift or modifier.Ctrl)) and CheckEnableAllyChat() then
				Spring.SendCommands("chatally")
			else
				Spring.SendCommands("chatall")
			end
			firstEnter = false
		end
		
		if options.backlogShowWithChatEntry.value then
			SetBacklogShow(true)
		end
		ShowInputSpace()
	else
		if options.backlogShowWithChatEntry.value then
			SetBacklogShow(false)
		end
		HideInputSpace()
	end
end

function widget:KeyRelease(key, modifier, isRepeat)
	if (key == KEYSYMS.RETURN) or (key == KEYSYMS.KP_ENTER) then
		if key == KEYSYMS.KP_ENTER and keypadEnterPressed then
			keypadEnterPressed = false
			return
		end
		if options.backlogShowWithChatEntry.value then
			SetBacklogShow(false)
		end
		HideInputSpace()
	end
	keypadEnterPressed = false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:MapDrawCmd(playerId, cmdType, px, py, pz, caption)
--	Spring.Echo("########### MapDrawCmd " .. playerId .. " " .. cmdType .. " coo="..px..","..py..","..pz .. (caption and (" caption " .. caption) or ''))
	if (cmdType == 'point') then
		widget:AddMapPoint(playerId, px, py, pz, caption) -- caption may be an empty string
		-- FIXME return true or false?
	end
end

function widget:AddMapPoint(playerId, px, py, pz, caption)
	local playerName, active, spec, teamId, allyTeamId = Spring.GetPlayerInfo(playerId, false)

	widget:AddConsoleMessage({
		msgtype = ((caption:len() > 0) and 'label' or 'point'),
		playername = playerName,
		source = getSource(spec, allyTeamId),
		text = 'MapDrawCmd ' .. caption,
		argument = caption,
		priority = 0, -- just in case ... probably useless
		point = { x = px, y = py, z = pz }
	})
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function isChat(msg)
	return msg.msgtype ~= 'other' or MessageIsChatInfo(msg)
end

local usernames = {}

-- new callin! will remain in widget
function widget:AddConsoleMessage(msg)
	if msg.msgtype == 'player_to_everyone' and msg.argument:find("whispered") then
		for i = 1, #usernames do
			local name = usernames[i]
			if msg.argument:find("whispered " .. name .. ":") then
				return
			end
		end
	end
	if msg.msgtype == 'other' then
		if options.error_opengl_source.value and (msg.argument):find('Error: OpenGL: source') then
			return
		end
		if options.filter_luaHandleCheckStack.value and (msg.argument):find("Warning: [LuaHandle::CheckStack] LuaRules stack-top", 0, true) then
			return
		end
		
		if (msg.argument):find('added point') then
			return
		end
		
		if (msg.argument):find("LuaMenuServerMessage") then
			return
		end
		
		if (msg.argument):find("GroundDetail set to") then
			return
		end
	end
	
	local isChat = isChat(msg)
	local isPoint = msg.msgtype == "point" or msg.msgtype == "label"
	local messages = isChat and chatMessages or consoleMessages
	if #messages > 0
		and messages[#messages].text == msg.text
		and (isPoint and options.dedupe_points.value or options.dedupe_messages.value)
		then
		
		if isPoint then
			-- update MapPoint position with most recent, as it is probably more relevant
			messages[#messages].point = msg.point
		end
		
		messages[#messages].dup = messages[#messages].dup + 1
		
		if isChat then
			AddMessage(messages[#messages], 'chat')
			AddMessage(messages[#messages], 'backchat')
		else
			AddMessage(messages[#messages], 'console')
		end
		return
	end
	
	msg.dup = 1
	
	detectHighlight(msg)
	formatMessage(msg) -- does not handle dedupe or highlight
	
	messages[#messages + 1] = msg
	
	if isChat then
		AddMessage(msg, 'chat')
		AddMessage(msg, 'backchat')
	else
		AddMessage(msg, 'console')
	end
	
	if msg.highlight and options.highlight_sound.value then
		PlaySound("highlight")
	elseif (msg.msgtype == "player_to_allies") or (msg.msgtype == "game_priority_message") then -- FIXME not for sent messages
		PlaySound("ally")
	elseif msg.msgtype == "label" then
		PlaySound("label")
	end

	if #messages > MAX_STORED_MESSAGES then
		table.remove(messages, 1)
	end
	
	removeToMaxLines()
end

-----------------------------------------------------------------------
local firstUpdate = true
local timer = 0

local initialSwapTime = 0.2
local firstSwap = true
local reload = false
local reloadTimer = 0

-- FIXME wtf is this obsessive function?
function widget:Update(s)
	if recentSoundTime then
		recentSoundTime = recentSoundTime - s
		if recentSoundTime < 0 then
			recentSoundTime = false
		end
	end
	timer = timer + s
	if timer > 2 then
		timer = 0
		local sub = 2 / options.autohide_text_time.value
		
		local inputWidthAdd = 0
		if not options.backlogArrowOnRight.value then
			inputWidthAdd = inputsize
		end
		
		Spring.SendCommands(
			{
				string.format("inputtextgeo %f %f 0.02 %f",
					(window_chat.x + inputWidthAdd)/ screen0.width + 0.003,
					1 - (window_chat.y + window_chat.height) / screen0.height + 0.004,
					window_chat.width / screen0.width
				)
			}
		)
		
		for k,control in pairs(fadeTracker) do
			fadeTracker[k].fade = math.max( control.fade - sub, 0 ) --removes old lines
			
			if control.fade == 0 then
				--control.parent:RemoveChild(control)
				control:Dispose()
				fadeTracker[k] = nil
			end
		end
	end
	if reload then
		reloadTimer = reloadTimer + s
		if reloadTimer > 0.6 then
			local buffer = widget:ProcessConsoleBuffer(nil, options.max_lines.value)
			for i=1,#buffer do
				widget:AddConsoleMessage(buffer[i])
			end
			reload = false
			reloadTimer = 0
		end
	end
	
	if firstUpdate then
		if options.defaultBacklogEnabled.value then
			SwapBacklog()
		end
		firstUpdate = false
		SetInputFontSize(15)
		if missionMode then
			SetHidden(true)
		end
	end
	
	-- Workaround bugged display on first open of the backlog
	if initialSwapTime then
		initialSwapTime = initialSwapTime - s
		if initialSwapTime < 0.1 and firstSwap then
			SwapBacklog()
			firstSwap = nil
		elseif initialSwapTime < 0 then
			SwapBacklog()
			SetBacklogShow(options.defaultBacklogEnabled.value)
			initialSwapTime = nil
		end
		if missionMode then
			SetHidden(true)
		end
	end
end

-----------------------------------------------------------------------

function widget:PlayerAdded(playerID)
	setupPlayers(playerID)
end

function widget:PlayerChanged(playerID)
	setupPlayers(playerID)
end

-----------------------------------------------------------------------
function widget:LocalColorRegister()
	if WG.LocalColor and WG.LocalColor.RegisterListener then
		WG.LocalColor.RegisterListener(widget:GetInfo().name, onOptionsChanged)
	end
end

function widget:LocalColorUnregister()
	if WG.LocalColor and WG.LocalColor.UnregisterListener then
		WG.LocalColor.UnregisterListener(widget:GetInfo().name)
	end
end

-----------------------------------------------------------------------

local function InitializeConsole()
	if stack_console then
		return
	end
	stack_console = MakeMessageStack(1)
	scrollpanel_console:AddChild(stack_console)

	for i = 1, #consoleMessages do
		local msg = consoleMessages[i]
		AddMessage(msg, 'console', true )
	end
	removeToMaxLines()
end

local function OnLocaleChanged()
	local newRecieved = WG.Translate("interface", "whisper") .. ": #w$argument"
	local newSent = WG.Translate("interface", "whisperto") .. ": #w$argument"
	local newSpec = WG.Translate("interface", "specwhisper") .. ": #w$argument"
	local newLabel = WG.Translate("interface", "addedpoint")
	local newMarker = WG.Translate("interface", "addedmarker")
	newSpec = newSpec:gsub('user2', "#t$playername2#w")
	newSpec = newSpec:gsub('user', "#p$playername#e")
	newSent = newSent:gsub("user", "#p$playername#e")
	newMarker = newMarker:gsub("user", "#p$playername#e")
	newLabel = newLabel:gsub("user", "#p$playername#e")
	newRecieved = newRecieved:gsub("user", "#p$playername#e")
	--Spring.Echo("Locale changed:\nSent: " .. newSent .. "\nRecieve: " .. newRecieved)
	MESSAGE_RULES.point.format = newLabel
	MESSAGE_RULES.player_to_player_received.format = newRecieved
	MESSAGE_RULES.player_to_player_sent.format = newSent
	MESSAGE_RULES.player_to_player_spec.format = newSpec
	MESSAGE_RULES.label.output[1].format = newMarker .. " $argument"
	MESSAGE_RULES.label.output[2].format = newMarker .. " #a$argument"
	MESSAGE_RULES.label.output[3].format = newMarker .. " #p$argument"
	reload = true
	if lastMsgChat then
		lastMsgChat:Dispose()
	end
	if lastMsgBackChat then
		lastMsgBackChat:Dispose()
	end
	if lastMsgConsole then
		lastMsgConsole:Dispose()
	end
	if stack_chat then
		for _, c in pairs(stack_chat.children) do
			stack_chat:RemoveChild(c) --dispose/disconnect all children (safer)
		end
		stack_chat:Invalidate()
	end
	if stack_console then
		for _, c in pairs(stack_console.children) do
			stack_console:RemoveChild(c)
		end
		stack_console:Invalidate()
	end
	if stack_backchat then
		for _, c in pairs(stack_backchat.children) do
			stack_backchat:RemoveChild(c)
		end
		stack_backchat:Invalidate()
	end
	if chatMessages and #chatMessages > 0 then
		for i = 1, #chatMessages do
			chatMessages[i] = nil
		end
	end
	RemakeConsole()
end

function SendPlayerResignedMessage(player1, player2, messageID)
	--Spring.Echo("SendPlayerResignedMessage: " .. tostring(messageID))
	local playerName1, _ = Spring.GetPlayerInfo(player1)
	local playerName2, _ = Spring.GetPlayerInfo(player2)
	local body
	local oldTeamID = select(4, Spring.GetPlayerInfo(player1))
	playerName1 = color2incolor(Spring.GetTeamColor(oldTeamID)) .. playerName1 .. incolors["#e"]
	if deathMessages then
		body = WG.Translate("interface", "death_"..messageID, {name = playerName1})
	else
		body = WG.Translate("interface", "death_normal", {name = playerName1})
	end
	if playerName2 then
		playerName2 = GetPlayerColor(playerName2) .. playerName2 .. incolors["#e"]
		body = body .. " " .. WG.Translate("interface", "giving_units", {name1 = playerName1, name2 = playerName2})
	end
	local m = {
			argument = body,
			priority = 35, -- wut?
			msgtype = 'game_message',
			text = body,
			argument = body,
		}
	widget:AddConsoleMessage(m)
end

function SendAFKMessage(player1, player2)
	if player1 == nil then
		Spring.Echo("Something has happened in SendAFKMessage! No playerID provided!")
		return
	end
	local playerName1, _ = Spring.GetPlayerInfo(player1)
	local playerName2, _ = Spring.GetPlayerInfo(player2)
	local body
	playerName1 = GetPlayerColor(playerName1) .. playerName1 .. incolors["#e"]
	--Spring.Echo(playerName1)
	if player2 then
		playerName2 = GetPlayerColor(playerName2) .. playerName2 .. incolors["#e"]
		body = WG.Translate("interface", "afk_given", {name = playerName1, name2 = playerName2})
	else
		body = WG.Translate("interface", "afk_returned", {name = playerName1, name2 = playerName2})
	end
	local allyTeam = select(5, Spring.GetPlayerInfo(player1))
	local allied = allyTeam == myAllyTeamId
	local m = {
			argument = body,
			priority = 35, -- wut?
			msgtype = 'game_priority_message',
			text = body,
			argument = body,
		}
	if not allied then m.msgtype = 'game_message' end
	widget:AddConsoleMessage(m)
end

local checkFrame = 0

function widget:Initialize()
	if (not WG.Chili) then
		widgetHandler:RemoveWidget()
		return
	end
	local pl = Spring.GetPlayerList()
	for i = 1, #pl do
		local n = Spring.GetPlayerInfo(pl[i])
		usernames[#usernames + 1] = n
	end
	
	screen0 = WG.Chili.Screen0
	color2incolor = WG.Chili.color2incolor
	
	Spring.SendCommands("bind Any+enter  chat")
	
	stack_chat = MakeMessageStack(0)
	deathMessages = options["death_messages"].value
	stack_backchat = MakeMessageStack(1)
	widgetHandler:RegisterGlobal("SendPlayerResignedMessage", SendPlayerResignedMessage)
	widgetHandler:RegisterGlobal("SendAFKMessage", SendAFKMessage)
	rainbowTable = {
		[1] = color2incolor({219/255, 15/255, 15/255, 1}),
		[2] = color2incolor({219/255, 15/255, 70/255, 1}),
		[3] = color2incolor({219/255, 15/255, 124/255, 1}),
		[4] = color2incolor({219/255, 15/255, 179/255, 1}),
		[5] = color2incolor({206/255, 15/255, 219/255, 1}),
		[6] = color2incolor({151/255, 15/255, 219/255, 1}),
		[7] = color2incolor({97/255, 15/255, 219/255, 1}),
		[8] = color2incolor({43/255, 15/255, 219/255, 1}),
		[9] = color2incolor({15/255, 43/255, 219/255, 1}),
		[10] = color2incolor({15/255, 97/255, 219/255, 1}),
		[11] = color2incolor({15/255, 151/255, 219/255, 1}),
		[12] = color2incolor({15/255, 206/255, 219/255, 1}),
		[13] = color2incolor({15/255, 219/255, 179/255, 1}),
		[14] = color2incolor({15/255, 219/255, 124/255, 1}),
		[15] = color2incolor({15/255, 219/255, 70/255, 1}),
		[16] = color2incolor({15/255, 219/255, 15/255, 1}),
		[17] = color2incolor({70/255, 219/255, 15/255, 1}),
		[18] = color2incolor({124/255, 219/255, 15/255, 1}),
		[19] = color2incolor({179/255, 219/255, 15/255, 1}),
		[20] = color2incolor({219/255, 206/255, 15/255, 1}),
		[21] = color2incolor({219/255, 151/255, 15/255, 1}),
		[22] = color2incolor({219/255, 97/255, 15/255, 1}),
		[23] = color2incolor({219/255, 43/255, 15/255, 1}),
	}
	inputspace = WG.Chili.ScrollPanel:New{
		x = (options.backlogArrowOnRight.value and 0) or inputsize,
		right = ((not options.backlogArrowOnRight.value) and 0) or inputsize,
		bottom = 0,
		noFont = true,
		height = inputsize,
		backgroundColor = {1,1,1,1},
		borderColor = {0,0,0,1},
		--backgroundColor = {1,1,1,1},
	}
	backlogButtonImage = WG.Chili.Image:New {
		width = "100%",
		height = "100%",
		keepAspect = true,
		--color = {0.7,0.7,0.7,0.4},
		file = 'LuaUI/Images/arrowhead.png',
	}
	backlogButton = WG.Chili.Button:New{
		name = "backlogButton",
		x = ((not options.backlogArrowOnRight.value) and 0) or nil,
		right = (options.backlogArrowOnRight.value and 0) or nil,
		bottom = 4,
		width = inputsize - 3,
		height = inputsize - 3,
		classname = "overlay_button_tiny",
		padding = {1,1,1,1},
		noFont = true,
		tooltip = 'Swap between decaying chat and scrollable chat backlog.',
		OnClick = {SwapBacklog},
		children={ backlogButtonImage },
	}
	
	scrollpanel_chat = WG.Chili.ScrollPanel:New{
		--margin = {5,5,5,5},
		padding = { 1,1,1,4 },
		x = 0,
		y = 0,
		width = '100%',
		noFont = true,
		bottom = inputsize + 2, -- This line is temporary until chili is fixed so that ReshapeConsole() works both times! -- TODO is it still required??
		verticalSmartScroll = true,
-- DISABLED FOR CLICKABLE TextBox		disableChildrenHitTest = true,
		backgroundColor = options.color_chat_background.value,
		borderColor = options.color_chat_background.value,
		ignoreMouseWheel = true,
		children = {
			stack_chat,
		},
		verticalScrollbar = false,
		horizontalScrollbar = false,
	}
	
	--spacer that forces chat to be scrolled to bottom of chat window
	WG.Chili.Panel:New{
		width = '100%',
		height = 500,
		backgroundColor = {0,0,0,0},
		parent = stack_chat,
	}
	
	scrollpanel_backchat = WG.Chili.ScrollPanel:New{
		--margin = {5,5,5,5},
		padding = { 3,3,3,3 },
		x = 0,
		y = 0,
		noFont = true,
		width = '100%',
		bottom = inputsize + 2, -- This line is temporary until chili is fixed so that ReshapeConsole() works both times! -- TODO is it still required??
		verticalSmartScroll = true,
		backgroundColor = options.color_chat_background.value,
		borderColor = {0,0,0,options.backchatOpacity.value},
		horizontalScrollbar = false,
		ignoreMouseWheel = not options.mousewheelBacklog.value,
		children = {
			stack_backchat,
		},
	}
	
	scrollpanel_console = WG.Chili.ScrollPanel:New{
		--margin = {5,5,5,5},
		padding = { 5, 5, 5, 5 },
		x = 5,
		y = 5,
		right = 5,
		bottom = 5,
		noFont = true,
		verticalSmartScroll = true,
		backgroundColor = {0,0,0,0},
		borderColor = {0,0,0,0},
		
		--ignoreMouseWheel = not options.mousewheel.value,
		children = {
		},
	}
	
	window_chat = MakeMessageWindow("ProChat", true)
	window_chat:AddChild(scrollpanel_chat)
	window_chat:AddChild(backlogButton)
	if options.enableChatBackground.value then
		window_chat:AddChild(inputspace)
	end
	
	window_console = MakeMessageWindow("ProConsole", options.enableConsole.value, InitializeConsole)
	window_console:AddChild(scrollpanel_console)
	self:LocalColorRegister()
	setupPlayers()
	RemakeConsole()
	--local buffer = widget:ProcessConsoleBuffer(nil, options.max_lines.value)
	--for i=1,#buffer do
	  --widget:AddConsoleMessage(buffer[i])
	--end
	
	Spring.SendCommands({"console 0"})
	
	HideInputSpace()
 	checkFrame = Spring.GetGameFrame() + 1
	WG.InitializeTranslation(OnLocaleChanged, GetInfo().name)
end

function widget:GameFrame(f)
	if f > checkFrame then
		setupPlayers() --re-check teamColor at gameStart for Singleplayer (special case. widget Initialized before player join).
		widgetHandler:RemoveCallIn("GameFrame", self)
	end
end

function widget:TextCommand(msg)
	local numberOfPlayers = #Spring.GetPlayerList()
	if msg == "testlabel" then
		Spring.MarkerAddPoint(math.random(1, 1000), 100, math.random(1, 1000), "Super Earth Will FALL", false, math.random(1, numberOfPlayers))
	end
	if msg == "testresign" then
		SendPlayerResignedMessage(Spring.GetMyPlayerID(), Spring.GetMyPlayerID(), 10)
	elseif msg == "testafk" then
		SendAFKMessage(Spring.GetMyPlayerID(), Spring.GetMyPlayerID())
		SendAFKMessage(Spring.GetMyPlayerID(), nil)
	end
end

function WG.ProConsoleAddFakeMsg(playerID, msg)
	local playerName, _, spectator, teamID, allyTeamID, _, _, _, _, customKeys = Spring.GetPlayerInfo(playerID, true)
	local m = {
		argument = msg,
		priority = 35, -- wut?
		msgtype = 'player_to_allies',
		text = msg,
		argument = msg,
		playername = playerName,
		player = {
			id = playerID,
			allyTeamId = allyTeamID,
			muted = (customKeys and customKeys.muted == 1),
			spec = spectator,
			playername = playerName,
			source = 'other', -- no idea what this does.
		},
	}
	widget:AddConsoleMessage(m)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,13) == "selectedcomm:" and not options.filter_commanderselection.value then
		local processedMsg = msg:sub(14)
		local splitPoint = processedMsg:find(",")
		local name = processedMsg:sub(1, splitPoint - 1)
		local chassis = processedMsg:sub(splitPoint + 1)
		local playerName, _, spectator, teamID, allyTeamID, _, _, _, _, customKeys = Spring.GetPlayerInfo(playerID, true)
		Spring.Echo("Got: " .. name .. ", " .. chassis .. " from " .. playerName)
		local body = WG.Translate("interface", "selected_commander", {commandername = name, commanderchassis = WG.Translate("interface", chassis)})
		Spring.Echo("Body: " .. body)
		local m = {
			argument = body,
			priority = 35, -- wut?
			msgtype = 'player_to_allies',
			text = body,
			argument = body,
			playername = playerName,
			player = {
				id = playerID,
				allyTeamId = allyTeamID,
				muted = (customKeys and customKeys.muted == 1),
				spec = spectator,
				playername = playerName,
				source = 'other', -- no idea what this does.
			},
		}
		widget:AddConsoleMessage(m)
	end
	if msg:sub(1,16) == 'LobbyChatUpdate_' then -- FIXME: why does an in-world object care about the overlay?
		local message = msg:sub(17, msg:len())
		if message then
			if options.send_lobby_updates.value then
				local toAdd = {
					formatted = "[" .. incolor_fromlobby .. "Lobby Message" .. "\255\255\255\255] " .. message,
					dup = 0,
				}
				AddMessage(toAdd, 'chat')
				AddMessage(toAdd, 'backchat')
			end
			if options.sound_for_lobby.value and not Spring.IsGameOver() then
				PlaySound('lobby')
			end
		end
	elseif msg:sub(1,10) == "whisperto_" then -- 'whisperto_<player2>,<msg>'
		msg = msg:gsub("whisperto_", "")
		local userEndIndex = msg:find(',')
		local senderName = msg:sub(1, userEndIndex - 1)
		--Spring.Echo("Sender is: " .. senderName)
		local recieverName, _, _, _, allyTeam = Spring.GetPlayerInfo(playerID, false)
		--Spring.Echo("Reciever is: " .. recieverName)
		local body = msg:sub(userEndIndex + 1, #msg)
		--Spring.Echo("Body is: " .. body)
		local m = {
			player = {
				id = playerID,
				allyTeamId = allyTeam,
				muted = false,
				spec = false,
				source = 'other',
				playername = recieverName,
				playername2 = senderName,
			},
			playername2 = senderName,
			playername = recieverName,
			argument = body,
			priority = 35,
			msgtype = 'player_to_player_spec',
			text = body,
		}
		widget:AddConsoleMessage(m)
	end
end

-----------------------------------------------------------------------

function widget:Shutdown()
	if (window_chat) then
		window_chat:Dispose()
	end
	SetInputFontSize(20)
	Spring.SendCommands({"console 1", "inputtextgeo default"}) -- not saved to spring's config file on exit
	Spring.SetConfigString("InputTextGeo", "0.26 0.73 0.02 0.028") -- spring default values
	
	self:LocalColorUnregister()
end
