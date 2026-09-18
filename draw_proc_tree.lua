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

		select_prev  = "Q", -- move the expanded selection to the previous proc
		select_next  = "W", -- move the expanded selection to the next proc
		script_up    = "E", -- scroll up within the expanded proc's script
		script_down  = "R", -- scroll down within the expanded proc's script
	},

	max_tree_depth = 10,
	name_col_width = 18,

	max_script_lines = 10, -- how many disassembled instructions to show at once for the expanded proc
	max_script_instructions = 200, -- safety cap on how far a single script is disassembled
}

display = true

name_col_width = config.name_col_width
starting_line = 0

-- selection state for the expanded proc script view
selected_index = 1 -- 1-based index (in print order) of the proc currently expanded
script_scroll = 0 -- scroll offset into the expanded proc's disassembly
visible_proc_count = 1 -- how many procs were printed last frame (used to clamp selection)
proc_counter = 0 -- running counter during the current frame's traversal

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

	if not suppressed then
		local marker = is_selected and "> " or "  "
		vba_console:print_line(string.rep("  ", depth) .. marker .. make_proc_string(procPointer, name_col_width - 2*depth - 2))
	end

	if is_selected then
		local start_addr = proc.proc_get_name(procPointer)
		local lines = proc.disassemble_script(start_addr, config.max_script_instructions)
		local last_line = math.min(#lines, script_scroll + config.max_script_lines)

		for i = script_scroll + 1, last_line do
			vba_console:print_line(string.rep("  ", depth + 1) .. lines[i])
		end

		if last_line < #lines then
			vba_console:print_line(string.rep("  ", depth + 1) .. "[...]")
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
	vba_console:print_line(string.format("%s/%s select proc  %s/%s scroll script", config.key.select_prev, config.key.select_next, config.key.script_up, config.key.script_down))
end

-- Uncomment the following to fix Proc Names in FE8U
-- memory.registerexec(0x08002C86, function()
	-- memory.writelong(memory.getregister("r0")+0x10, 0)
-- end)

-- same thing for aw2 but sadly doesn't seem to work
memory.registerexec(0x0801c8fe, function()
	-- memory.writelong(memory.getregister("r0")+0x00, 0)
	-- memory.writelong(memory.getregister("r0")+0x04, 0)
	-- memory.writelong(memory.getregister("r0")+0x08, 0)
	-- memory.writelong(memory.getregister("r0")+0x0C, 0)
	memory.writelong(memory.getregister("r0")+0x10, 0)
	-- memory.writelong(memory.getregister("r0")+0x14, 0)
	-- memory.writelong(memory.getregister("r0")+0x18, 0)
	-- memory.writelong(memory.getregister("r0")+0x1C, 0)
	-- memory.writelong(memory.getregister("r0")+0x20, 0)
	-- memory.writelong(memory.getregister("r0")+0x24, 0)
	-- memory.writelong(memory.getregister("r0")+0x28, 0)
	-- memory.writelong(memory.getregister("r0")+0x2C, 0)
	-- memory.writelong(memory.getregister("r0")+0x30, 0)
end)

-- for ProcJump in aw2
memory.registerexec(0x0801cc00, function()
	-- memory.writelong(memory.getregister("r0"), memory.getregister("r1"))
	-- memory.writelong(memory.getregister("r0")+0x04, 0)
	-- memory.writelong(memory.getregister("r0")+0x08, 0)
	-- memory.writelong(memory.getregister("r0")+0x0C, 0)
	-- memory.writelong(memory.getregister("r0")+0x10, 0)
	-- memory.writelong(memory.getregister("r0")+0x14, 0)
	-- memory.writelong(memory.getregister("r0")+0x18, 0)
	-- memory.writelong(memory.getregister("r0")+0x1C, 0)
	-- memory.writelong(memory.getregister("r0")+0x20, 0)
	-- memory.writelong(memory.getregister("r0")+0x24, 0)
	-- memory.writelong(memory.getregister("r0")+0x28, 0)
end)


gui.register(function()
	handle_input()

	if display then
		vba_console:begin_frame(starting_line)
	end

	proc_counter = 0

	for i, pointer in proc.tree_iterator() do
		vba_console:print_line("TREE #" .. i)

		for struct in proc.proc_iterator(pointer) do
			print_proc(1, struct)
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
print(string.format("Use %s and %s to navigate tree", config.key.scroll_up, config.key.scroll_down))
print(string.format("Use %s and %s to change name column size", config.key.expand_name, config.key.shrink_name))
print(string.format("Use %s and %s to select which proc's script is expanded", config.key.select_prev, config.key.select_next))
print(string.format("Use %s and %s to scroll the expanded proc's script", config.key.script_up, config.key.script_down))
