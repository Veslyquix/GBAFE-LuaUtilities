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
	},
	
	max_tree_depth = 10,
	name_col_width = 18
}

display = true

name_col_width = config.name_col_width
starting_line = 0

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

function print_proc(depth, procPointer)
	if depth > config.max_tree_depth then
		vba_console:print_line(string.rep("  ", depth) .. "[...]")
	elseif not (procPointer == 0) then
		vba_console:print_line(string.rep("  ", depth) .. make_proc_string(procPointer, name_col_width - 2*depth))
		
		-- Drawing Children
		for child in proc.child_iterator(procPointer) do
			print_proc(depth + 1, child)
		end
	end
end

function print_footer()
	vba_console:print_line(wsextend_string("Name", name_col_width) .. " pointer+pc")
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
	
	for i, pointer in proc.tree_iterator() do
		vba_console:print_line("TREE #" .. i)
		
		for struct in proc.proc_iterator(pointer) do
			print_proc(1, struct)
		end
	end
	
	if vba_console.current_line < 18 then
		vba_console.current_line = 18
		print_footer()
	end
end)

print(" - GBAFE PROC TREE DRAWING SCRIPT - (author: StanH_)")
print(string.format("Use %s to toggle tree display on or off", config.key.toggle))
print(string.format("Use %s and %s to navigate tree", config.key.scroll_up, config.key.scroll_down))
print(string.format("Use %s and %s to change name column size", config.key.expand_name, config.key.shrink_name))
