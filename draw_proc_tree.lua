require "util/proc"
require "util/vba_console"
require "util/press_input"
require "util/aw2_frame_tree"

-- Config
config = {
	key = {
		toggle            = "T", -- show/hide the whole display
		toggle_script     = "E", -- show/hide the selected proc's script
		toggle_leaf_calls = "R", -- hide/show plain calls in the per-frame call tree

		select_prev = "Q", -- previous section: main hook, aux hook, or a proc
		select_next = "W", -- next section
		cursor_up   = "D", -- move the cursor within the selected section
		cursor_down = "F",

		-- Disabled (nil) for now. Set a key name to bring any of them back;
		-- their handling below is still in place.
		scroll_up   = nil, -- "F5": manual scroll. Q/W/D/F already keep the cursor on screen,
		scroll_down = nil, -- "F4"  and the view snaps back to the cursor after a manual scroll.
		expand_name = nil, -- "F3": widen the proc name column
		shrink_name = nil, -- "F2": narrow the proc name column
	},

	max_tree_depth = 10,
	name_col_width = 18,

	max_script_lines = 10, -- how many disassembled instructions to show at once for the expanded proc
	max_script_instructions = 200, -- safety cap on how far a single script is disassembled

	cursor_context = 2, -- lines kept visible above/below the cursor when scrolling to it
	repeat_delay = 10, -- extra frames a cursor key must be held before it starts repeating
	repeat_rate = 7, -- frames between repeats while held
	debug_keys = false, -- print what input.get() reports for Q/W/D/F each frame

	color = {
		blocked = 0xFF9090FF, -- slightly red: proc is blocked (e.g. by a blocking child)
		active  = 0x90FF90FF, -- slightly green: proc/instruction is actively running
		waiting = 0xFFFF90FF, -- slightly yellow: blocked proc's current instruction

		-- per-frame call tree (while gUnknown_03003F3C == 1); active calls use the default colour
		call = {
			unknown = 0xFFFF90FF, -- condition above it can't be read from RAM
			skipped = 0xFF9090FF, -- not reached this frame
		},
	},
}

display = true
show_script = true
hide_leaf_calls = false

name_col_width = config.name_col_width
scroll = 0 -- first buffered line shown at the top of the display (0-based)

-- Navigation. Each frame the display is split into "sections" (targets), in
-- print order: the main hook, the aux hook and every proc. Q/W pick the
-- section, D/F move the cursor inside it - through the hook's calls, or
-- through the selected proc's script.
selected_target = 1 -- 1-based index into this frame's targets
cursor = 1 -- 1-based cursor inside the selected target
cursor_reset = true -- selection changed: put the cursor somewhere sensible
script_scroll = 0 -- scroll offset into the expanded proc's disassembly

-- rebuilt every frame
lines = {} -- {text, color}
targets = {} -- {kind, first_line, items (hooks: line indices), cursor_line}

key_held = {}

function key_pressed(key)
	return key ~= nil and press_input:is_pressed(key)
end

-- pressed, or held long enough to auto-repeat
function key_repeated(key)
	if key == nil then
		return false
	end

	if not press_input._current[key] then
		key_held[key] = 0
		return false
	end

	local frames = (key_held[key] or 0) + 1
	key_held[key] = frames

	-- fires on the first frame, then every repeat_rate frames once past repeat_delay
	return frames == 1 or (frames > config.repeat_delay + 1 and (frames - 1 - config.repeat_delay) % config.repeat_rate == 0)
end

debug_frame = 0

function handle_input()
	press_input:update()

	if config.debug_keys then
		debug_frame = debug_frame + 1
		local held = ""

		for _, name in ipairs({ "select_prev", "select_next", "cursor_up", "cursor_down" }) do
			local key = config.key[name]

			if key ~= nil and press_input._current[key] then
				held = held .. key .. "(" .. ((key_held[key] or 0) + 1) .. ") "
			end
		end

		if held ~= "" then
			print(string.format("frame %d: %s", debug_frame, held))
		end
	end

	if key_pressed(config.key.scroll_up) then
		scroll = scroll - 1
	end

	if key_pressed(config.key.scroll_down) then
		scroll = scroll + 1
	end

	if key_pressed(config.key.expand_name) then
		name_col_width = name_col_width + 2
	end

	if key_pressed(config.key.shrink_name) then
		name_col_width = name_col_width - 2
	end

	if key_pressed(config.key.toggle) then
		display = not display
	end

	if key_pressed(config.key.toggle_script) then
		show_script = not show_script
		cursor_reset = true
	end

	if key_pressed(config.key.toggle_leaf_calls) then
		hide_leaf_calls = not hide_leaf_calls
	end

	if key_repeated(config.key.select_prev) then
		selected_target = math.max(1, selected_target - 1)
		cursor_reset = true
	end

	if key_repeated(config.key.select_next) then
		selected_target = selected_target + 1 -- clamped once this frame's targets are known
		cursor_reset = true
	end

	if key_repeated(config.key.cursor_up) then
		cursor = math.max(1, cursor - 1)
	end

	if key_repeated(config.key.cursor_down) then
		cursor = cursor + 1 -- clamped by whatever the cursor lands in
	end
end

function emit(text, color)
	table.insert(lines, { text = text, color = color })
	return #lines
end

-- starts a new navigable section; returns it and whether it's the selected one
function begin_target(kind, first_line)
	local target = { kind = kind, first_line = first_line or (#lines + 1), items = {} }
	table.insert(targets, target)
	return target, #targets == selected_target
end

-- swaps the two spaces before a line's text for a "> " cursor marker
function mark_line(index)
	local line = lines[index]

	if line == nil then
		return
	end

	local spaces = line.text:match("^ *"):len()

	if spaces >= 2 then
		line.text = string.rep(" ", spaces - 2) .. "> " .. line.text:sub(spaces + 1)
	else
		line.text = "> " .. line.text
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

function print_proc_script(depth, procPointer, target, is_blocked)
	local start_addr = proc.proc_get_name(procPointer)
	local instructions = proc.disassemble_script(start_addr, config.max_script_instructions)
	local active_index = proc.proc_get_active_instruction_index(procPointer, instructions)

	if cursor_reset then
		cursor = active_index or 1
		cursor_reset = false
	end

	cursor = math.max(1, math.min(cursor, #instructions))

	-- keep the cursor inside the script window
	script_scroll = math.min(script_scroll, cursor - 1)
	script_scroll = math.max(script_scroll, cursor - config.max_script_lines)
	script_scroll = math.max(0, math.min(script_scroll, #instructions - config.max_script_lines))

	local last_line = math.min(#instructions, script_scroll + config.max_script_lines)
	local indent = string.rep("  ", depth + 1)

	if script_scroll > 0 then
		emit(indent .. "[...]", is_blocked and config.color.blocked or nil)
	end

	for i = script_scroll + 1, last_line do
		local line_color = nil

		if is_blocked and i == active_index then
			line_color = config.color.waiting
		elseif is_blocked then
			line_color = config.color.blocked
		elseif i == active_index then
			line_color = config.color.active
		end

		local index = emit(indent .. instructions[i].text, line_color)

		if i == cursor then
			target.cursor_line = index
		end
	end

	if last_line < #instructions then
		emit(indent .. "[...]", is_blocked and config.color.blocked or nil)
	end
end

-- `suppressed` is true while walking the descendants of a currently-expanded
-- proc: their lines aren't drawn (the expanded proc's script is shown instead),
-- but they still need to be visited so their target slots are reserved -
-- otherwise selection would skip straight over them to the next sibling/tree.
function print_proc(depth, procPointer, suppressed)
	if depth > config.max_tree_depth then
		if not suppressed then
			emit(string.rep("  ", depth) .. "[...]")
		end
		return
	end

	if procPointer == 0 then
		return
	end

	local target, is_selected = begin_target("proc", suppressed and #lines or nil)
	is_selected = is_selected and not suppressed
	local should_expand = show_script and is_selected
	local is_blocked = proc.proc_is_inactive(procPointer) -- lockCnt != 0, or stuck at PROC_BLOCK
	local title_color = is_blocked and config.color.blocked or config.color.active

	if not suppressed then
		local marker = is_selected and "> " or "  "
		emit(string.rep("  ", depth) .. marker .. make_proc_string(procPointer, name_col_width - 2*depth - 2), title_color)
	end

	if should_expand then
		print_proc_script(depth, procPointer, target, is_blocked)

		-- still walk children so their target slots are reserved for navigation
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

-- same lookup as proc.tree_iterator, for a single gProcTreeRootArray index
function proc_tree_root(tree)
	local pointer = memory.readlong(proc.get_reference().ptr_proc_forest + 4*tree)

	if pointer == 0 then
		pointer = proc.proc_find_tree_root(tree)
	end

	return pointer
end

function print_proc_tree(depth, tree)
	local before = #targets

	for struct in proc.proc_iterator(proc_tree_root(tree)) do
		print_proc(depth, struct)
	end

	return #targets > before
end

function call_node_is_leaf(node)
	return node.children == nil and node.switch == nil and node.proc_tree == nil and node.when == nil and not node.keep
end

-- Draws one node of the per-frame call tree (see util/aw2_frame_tree.lua).
-- `hook` is the hook target the node's line belongs to, for D/F navigation.
-- `state` is inherited from the parent: "active", "unknown" (a condition
-- above it can't be evaluated from RAM) or "skipped" (not reached this frame).
-- Skipped nodes are drawn but not expanded. `force` draws the node even if
-- it's a plain call that hide_leaf_calls would otherwise hide.
function print_call_node(hook, depth, node, state, force)
	if depth > config.max_tree_depth then
		emit(string.rep("  ", depth) .. "[...]")
		return
	end

	if node.proc_tree ~= nil then
		frame_trees_seen[node.proc_tree] = true
	end

	local detail = nil

	if node.when ~= nil and state ~= "skipped" then
		local ok
		ok, detail = node.when()

		if ok == false then
			state = "skipped"
		elseif ok == nil and state == "active" then
			state = "unknown"
		end
	end

	if hide_leaf_calls and not force and call_node_is_leaf(node) then
		return
	end

	local line = string.rep("  ", depth) .. node.name

	if node.proc_tree ~= nil then
		line = line .. "(tree " .. node.proc_tree .. ")"
	end

	local switch_value = nil

	if node.switch ~= nil and state ~= "skipped" then
		switch_value = node.switch.read()
		line = line .. string.format(" [%s=%d]", node.switch.label, switch_value)
	end

	if node.note ~= nil then
		line = line .. " - " .. node.note
	end

	if detail ~= nil then
		line = line .. " (" .. detail .. ")"
	end

	table.insert(hook.items, emit(line, config.color.call[state]))

	if state == "skipped" then
		return
	end

	if node.proc_tree ~= nil then
		if not print_proc_tree(depth + 1, node.proc_tree) and not hide_leaf_calls then
			emit(string.rep("  ", depth + 1) .. "[empty]")
		end
	end

	if node.switch ~= nil then
		local case = node.switch.cases[switch_value]

		if case ~= nil then
			print_call_node(hook, depth + 1, case, state, true) -- the selected case is the point of the switch, never hide it
		else
			emit(string.rep("  ", depth + 1) .. "[no case]", config.color.call.skipped)
		end
	end

	local children = node.children

	if type(children) == "function" then
		children = children()
	end

	if children ~= nil then
		for _, child in ipairs(children) do
			print_call_node(hook, depth + 1, child, state)
		end
	end
end

-- Replaces the plain proc tree listing while gUnknown_03003F3C == 1: starts
-- from the main/aux frame hooks and walks everything they call each frame,
-- with the proc trees drawn where Proc_Run runs them.
function print_frame_tree()
	frame_trees_seen = {}

	for _, hook in ipairs(aw2_frame_tree.hook_addresses) do
		local address = memory.readlong(hook.address)
		local node = aw2_frame_tree.hooks[address - (address % 2)]
		local label = string.upper(hook.label) .. " HOOK"

		if node ~= nil then
			local target, is_selected = begin_target("hook")
			emit(is_selected and ("[" .. label .. "]") or label)
			print_call_node(target, 1, node, "active")
		else
			emit(string.format("%s 0x%08X (no call spec)", label, address))
		end
	end

	-- trees that exist but aren't run by either hook's spec
	for i = 0, proc.get_reference().proc_forest_size - 1 do
		if not frame_trees_seen[i] and proc.proc_is_allocated(proc_tree_root(i)) then
			emit("TREE #" .. i .. " (not run by hooks)")
			print_proc_tree(1, i)
		end
	end
end

function print_proc_forest()
	for i, pointer in proc.tree_iterator() do
		emit("TREE #" .. i)

		for struct in proc.proc_iterator(pointer) do
			print_proc(1, struct)
		end
	end

	if #targets == 0 then
		emit("PROC POOL")

		for struct in proc.pool_iterator() do
			print_proc(1, struct)
		end

		if #targets == 0 then
			emit("  [no active procs]")
		end
	end
end

-- places the cursor for the selected hook (proc cursors are placed while
-- their script is printed) and marks it
function finish_selection()
	local target = targets[selected_target]

	if target == nil then
		return nil
	end

	if target.kind == "hook" then
		if cursor_reset then
			cursor = 1
		end

		cursor = math.max(1, math.min(cursor, #target.items))
		target.cursor_line = target.items[cursor]

		if target.cursor_line ~= nil then
			mark_line(target.cursor_line)
		end
	elseif target.cursor_line ~= nil then
		mark_line(target.cursor_line)
	end

	cursor_reset = false

	return target.cursor_line or target.first_line
end

function display_rows()
	return math.floor((vba_console.geometry.h - vba_console.margin.y*2) / 8)
end

-- moves `scroll` the least amount needed to show `line` (1-based) with some
-- context around it, without scrolling past the end of the buffer
function scroll_to(line)
	local rows = display_rows()
	local row = line - 1
	local context = math.min(config.cursor_context, math.floor((rows - 1) / 2))

	scroll = math.min(scroll, row - context)
	scroll = math.max(scroll, row + context - rows + 1)
	scroll = math.max(0, math.min(scroll, #lines - rows))
end

function print_footer()
	local k = config.key
	vba_console:print_line(string.format("%s hide  %s scripts  %s plain calls", k.toggle, k.toggle_script, k.toggle_leaf_calls))
	vba_console:print_line(string.format("%s/%s select section  %s/%s move cursor", k.select_prev, k.select_next, k.cursor_up, k.cursor_down))
end

gui.register(function()
	handle_input()

	lines = {}
	targets = {}

	if aw2_frame_tree.is_active() then
		print_frame_tree()
	else
		print_proc_forest()
	end

	-- the last frame's selection may be gone (e.g. a proc ended)
	if #targets > 0 and selected_target > #targets then
		selected_target = #targets
		cursor_reset = true
		lines = {}
		targets = {}

		if aw2_frame_tree.is_active() then
			print_frame_tree()
		else
			print_proc_forest()
		end
	end

	local cursor_line = finish_selection()

	if cursor_line ~= nil then
		scroll_to(cursor_line)
	else
		scroll = math.max(0, math.min(scroll, #lines - display_rows()))
	end

	if not display then
		return
	end

	vba_console:begin_frame(-scroll)

	for _, line in ipairs(lines) do
		vba_console:print_line(line.text, line.color)
	end

	local footer_row = display_rows() - 2

	if vba_console.current_line <= footer_row then
		vba_console.current_line = footer_row
		print_footer()
	end
end)

print(" - GBAFE PROC TREE DRAWING SCRIPT - (author: StanH_)")
print(string.format("Use %s to toggle tree display on or off", config.key.toggle))
print(string.format("Use %s to toggle expanded proc script display", config.key.toggle_script))
print(string.format("Use %s to hide/show plain calls in the per-frame call tree (AW2 map)", config.key.toggle_leaf_calls))
print(string.format("Use %s and %s to select the main hook, aux hook or a proc to expand", config.key.select_prev, config.key.select_next))
print(string.format("Use %s and %s to move the cursor within the selected hook or proc script", config.key.cursor_up, config.key.cursor_down))

if config.key.scroll_up ~= nil and config.key.scroll_down ~= nil then
	print(string.format("Use %s and %s to navigate tree", config.key.scroll_up, config.key.scroll_down))
end

if config.key.expand_name ~= nil and config.key.shrink_name ~= nil then
	print(string.format("Use %s and %s to change name column size", config.key.expand_name, config.key.shrink_name))
end
