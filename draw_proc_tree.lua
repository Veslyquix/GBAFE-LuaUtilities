require "util/proc"
require "util/vba_console"
require "util/press_input"

-- Config
config = {
	key = {
		scroll_up   = "F5",
		scroll_down = "F4",

		expand_name = "F3",
		shrink_name = "F2",

		toggle      = "F6",
		toggle_script = "F1",

		select_prev  = "Q", -- move the expanded selection to the previous proc
		select_next  = "W", -- move the expanded selection to the next proc
		script_up    = "E", -- scroll up within the expanded proc's script
		script_down  = "R", -- scroll down within the expanded proc's script
	},

	max_tree_depth = 10,
	name_col_width = 18,

	max_script_lines = 10, -- how many disassembled instructions to show at once for the expanded proc
	max_script_instructions = 200, -- safety cap on how far a single script is disassembled

	color = {
		blocked = 0xFF9090FF, -- slightly red: proc is blocked (e.g. by a blocking child)
		active  = 0x90FF90FF, -- slightly green: proc/instruction is actively running
		waiting = 0xFFFF90FF, -- slightly yellow: blocked proc's current instruction
	},
}

display = true
show_script = true

name_col_width = config.name_col_width
starting_line = 0

-- selection state for the expanded proc script view
selected_index = 1 -- 1-based index (in print order) of the proc currently expanded
script_scroll = 0 -- scroll offset into the expanded proc's disassembly
visible_proc_count = 1 -- how many procs were printed last frame (used to clamp selection)
proc_counter = 0 -- running counter during the current frame's traversal

design_room = {
	ptr_state = 0x0200B0B0,
	storage = 0x0200B000,
}

root_hooks = {
	main = 0x030040D0,
	aux = 0x030040EC,
	frame = 0x03004008,
	phase_done = 0x03004094,
	frame_mask = 0x030043F4,
	in_immediate_copy = 0x030044D0,

	names = {
		[0x0802E920] = "sub_0802E920",
		[0x0802E940] = "sub_0802E940",
		[0x0802E960] = "sub_0802E960",
		[0x08036884] = "sub_08036884",
		[0x080368E8] = "sub_080368E8",
		[0x08036944] = "sub_08036944 (design/main)",
		[0x080369BC] = "sub_080369BC (design/aux)",
		[0x08036A50] = "sub_08036A50",
		[0x08036AB8] = "sub_08036AB8",
	},
}

function handle_input()
	press_input:update()

	if press_input:is_pressed(config.key.scroll_up) then
		starting_line = starting_line - 1
	end

	if press_input:is_pressed(config.key.scroll_down) then
		starting_line = starting_line + 1
	end

	if press_input:is_pressed(config.key.expand_name) then
		name_col_width = name_col_width + 2
	end

	if press_input:is_pressed(config.key.shrink_name) then
		name_col_width = name_col_width - 2
	end

	if press_input:is_pressed(config.key.toggle) then
		display = not display
	end

	if press_input:is_pressed(config.key.toggle_script) then
		show_script = not show_script
	end

	if press_input:is_pressed(config.key.select_prev) then
		selected_index = math.max(1, selected_index - 1)
		script_scroll = 0
	end

	if press_input:is_pressed(config.key.select_next) then
		selected_index = math.min(visible_proc_count, selected_index + 1)
		script_scroll = 0
	end

	if press_input:is_pressed(config.key.script_up) then
		script_scroll = math.max(0, script_scroll - 1)
	end

	if press_input:is_pressed(config.key.script_down) then
		script_scroll = script_scroll + 1
	end
end

function wsextend_string(str, minLength)
	if str:len() < minLength then
		str = str .. string.rep(" ", minLength - str:len())
	end

	return str
end

function make_proc_string(procPointer, nameLength)
	return string.format("%s %s", wsextend_string(proc.proc_read_name(procPointer), nameLength), proc.proc_get_state_summary(procPointer))
end

function read_s8(address)
	local value = memory.readbyte(address)

	if value >= 0x80 then
		value = value - 0x100
	end

	return value
end

function read_s16(address)
	local value = memory.readshort(address)

	if value >= 0x8000 then
		value = value - 0x10000
	end

	return value
end

function design_room_get_state()
	local pointer = memory.readlong(design_room.ptr_state)

	if pointer ~= design_room.storage then
		return nil
	end

	return pointer
end

function design_room_mode_name(mode)
	local names = {
		[0] = "opening script",
		[1] = "map edit",
		[2] = "unit menu",
		[3] = "terrain/menu",
		[5] = "exit prompt",
		[6] = "script wait",
		[7] = "closing",
		[9] = "idle",
	}

	return names[mode] or "unknown"
end

function normalize_thumb_address(address)
	if address % 2 == 1 then
		return address - 1
	end

	return address
end

function root_hook_name(address)
	local normalized = normalize_thumb_address(address)
	local name = root_hooks.names[normalized]

	if name ~= nil then
		return name
	end

	if normalized == 0 then
		return "none"
	end

	return string.format("0x%08X", normalized)
end

function print_root_hooks()
	local main = memory.readlong(root_hooks.main)
	local aux = memory.readlong(root_hooks.aux)
	local frame = memory.readlong(root_hooks.frame)
	local phase_done = memory.readbyte(root_hooks.phase_done)
	local frame_mask = memory.readlong(root_hooks.frame_mask)
	local in_immediate_copy = memory.readbyte(root_hooks.in_immediate_copy)

	vba_console:print_line("ROOT HOOKS")
	vba_console:print_line(string.format("  main 0x%08X %s", main, root_hook_name(main)))
	vba_console:print_line(string.format("  aux  0x%08X %s", aux, root_hook_name(aux)))
	vba_console:print_line(string.format("  frame %d  mask 0x%X  phase %d  dma-now %d", frame, frame_mask, phase_done, in_immediate_copy))
end

function print_design_room_state()
	local state = design_room_get_state()

	if state == nil then
		return false
	end

	local flags = memory.readshort(state + 0x00)
	local substate = memory.readshort(state + 0x02)
	local mode = memory.readshort(state + 0x04)
	local pending = read_s8(state + 0x06)
	local side = read_s8(state + 0x07)
	local cursor_x = read_s16(state + 0x08)
	local cursor_y = read_s16(state + 0x0A)
	local timer = memory.readlong(state + 0x0C)
	local action = memory.readshort(state + 0x2A)
	local unit = memory.readshort(state + 0x24)
	local list_index = memory.readshort(state + 0x28)
	local ring_index = read_s16(state + 0x3A)
	local panel = read_s16(state + 0x3E)

	vba_console:print_line("DESIGN ROOM")
	vba_console:print_line(string.format("  mode %d (%s)  substate %d  pending %d", mode, design_room_mode_name(mode), substate, pending))
	vba_console:print_line(string.format("  cursor (%d,%d)  side %d  timer %d", cursor_x, cursor_y, side, timer))
	vba_console:print_line(string.format("  action 0x%X  unit 0x%X  list %d  ring %d", action, unit, list_index, ring_index))
	vba_console:print_line(string.format("  flags 0x%04X  panel %d  state 0x%08X", flags, panel, state))
	print_root_hooks()

	return true
end

-- `suppressed` is true while walking the descendants of a currently-expanded
-- proc: their lines aren't drawn (the expanded proc's script is shown instead),
-- but they still need to be visited so their index slots are reserved -
-- otherwise selection would skip straight over them to the next sibling/tree.
function print_proc(depth, procPointer, suppressed)
	if depth > config.max_tree_depth then
		if not suppressed then
			vba_console:print_line(string.rep("  ", depth) .. "[...]")
		end
		return
	end

	if procPointer == 0 then
		return
	end

	proc_counter = proc_counter + 1
	local is_selected = (proc_counter == selected_index) and not suppressed
	local should_expand = show_script and is_selected
	local is_blocked = proc.proc_is_inactive(procPointer) -- lockCnt != 0, or stuck at PROC_BLOCK
	local title_color = is_blocked and config.color.blocked or config.color.active

	if not suppressed then
		local marker = should_expand and "> " or "  "
		vba_console:print_line(string.rep("  ", depth) .. marker .. make_proc_string(procPointer, name_col_width - 2*depth - 2), title_color)
	end

	if should_expand then
		local start_addr = proc.proc_get_name(procPointer)
		local instructions = proc.disassemble_script(start_addr, config.max_script_instructions)
		local active_index = proc.proc_get_active_instruction_index(procPointer, instructions)
		local last_line = math.min(#instructions, script_scroll + config.max_script_lines)

		for i = script_scroll + 1, last_line do
			local line_color = nil

			if is_blocked and i == active_index then
				line_color = config.color.waiting
			elseif is_blocked then
				line_color = config.color.blocked
			elseif i == active_index then
				line_color = config.color.active
			end

			vba_console:print_line(string.rep("  ", depth + 1) .. instructions[i].text, line_color)
		end

		if last_line < #instructions then
			vba_console:print_line(string.rep("  ", depth + 1) .. "[...]", is_blocked and config.color.blocked or nil)
		end

		-- still walk children so their index slots are reserved for navigation
		for child in proc.child_iterator(procPointer) do
			print_proc(depth + 1, child, true)
		end
	else
		-- Drawing Children
		for child in proc.child_iterator(procPointer) do
			print_proc(depth + 1, child, suppressed)
		end
	end
end

function print_footer()
	vba_console:print_line(wsextend_string("Name", name_col_width) .. " pointer+pc")
	vba_console:print_line(string.format("%s scripts  %s/%s select proc  %s/%s scroll script", config.key.toggle_script, config.key.select_prev, config.key.select_next, config.key.script_up, config.key.script_down))
end

function print_design_room_procs()
	local printed_header = false

	for struct in proc.pool_iterator() do
		if not printed_header then
			vba_console:print_line("PROCS")
			printed_header = true
		end

		print_proc(1, struct)
	end
end

gui.register(function()
	handle_input()

	if display then
		vba_console:begin_frame(starting_line)
	end

	proc_counter = 0
	local in_design_room = design_room_get_state() ~= nil

	if in_design_room then
		print_design_room_state()
		print_design_room_procs()
	else
		for i, pointer in proc.tree_iterator() do
			vba_console:print_line("TREE #" .. i)

			for struct in proc.proc_iterator(pointer) do
				print_proc(1, struct)
			end
		end

		if proc_counter == 0 then
			vba_console:print_line("PROC POOL")

			for struct in proc.pool_iterator() do
				print_proc(1, struct)
			end

			if proc_counter == 0 then
				vba_console:print_line("  [no active procs]")
			end
		end
	end

	visible_proc_count = math.max(1, proc_counter)
	selected_index = math.min(selected_index, visible_proc_count)

	if vba_console.current_line < 18 then
		vba_console.current_line = 18
		print_footer()
	end
end)

print(" - GBAFE PROC TREE DRAWING SCRIPT - (author: StanH_)")
print(string.format("Use %s to toggle tree display on or off", config.key.toggle))
print(string.format("Use %s to toggle expanded proc script display", config.key.toggle_script))
print(string.format("Use %s and %s to navigate tree", config.key.scroll_up, config.key.scroll_down))
print(string.format("Use %s and %s to change name column size", config.key.expand_name, config.key.shrink_name))
print(string.format("Use %s and %s to select which proc's script is expanded", config.key.select_prev, config.key.select_next))
print(string.format("Use %s and %s to scroll the expanded proc's script", config.key.script_up, config.key.script_down))
