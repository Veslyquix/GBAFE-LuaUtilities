require "util/gba"

-- Loads util/names/<code>.lua (hand-picked names), optionally layered on top
-- of a base table (e.g. auto-generated decomp symbols) whose entries it
-- overrides on collision. Missing name files just yield no hand-picked names.
local function load_names(code, base)
	local result = {}

	if base ~= nil then
		for address, name in pairs(base) do
			result[address] = name
		end
	end

	local ok, curated = pcall(require, "util/names/" .. code)

	if ok then
		for address, name in pairs(curated) do
			result[address] = name
		end
	end

	return result
end

proc = {
	references = {
        AW2E = { -- AW2U (see rom header + 0xAC)
        -- [849EB7C..849EB84]? -- break point on known proc data read on new campaign
        -- 1c8f4 proc start? r0 ProcPtr, r1 root tree -- went to r14 a couple times?
            -- calls 1d264
            ptr_proc_pool = 0x200D610,
            proc_pool_size = 0x20,
        -- 200e390 is sProcAllocList, 200e414 is sProcAllocListHead
        -- 200e418 - 200e434 is gProcTreeRootArray
            ptr_proc_forest = 0x200e418,
            proc_forest_size = 8,
        -- [84C3138+0x40..84C3138+0x47]? // 8th entry in LoadBattleMap proc at 0x084C3138
        -- hits 0x801CFC8 as InitSleep
        -- [200d6e8+0x24]? ProcRam+0x24 as sleep timer
        -- hits 0x801CFAC as UpdateSleep
            ptr_sleep_handle = 0x801cfad,
			-- decomp symbols (util/names/AW2E_decomp.lua) as a base, with
			-- hand-picked names (util/names/AW2E.lua) taking priority
			names = load_names("AW2E", require "util/names/AW2E_decomp")
        --

        },
		BE8E = {
			-- FE8U

			ptr_proc_forest  = 0x02026A70, -- gProcTreeRootArray
			proc_forest_size = 8,

			ptr_proc_pool    = 0x02024E68, -- sProcArray
			proc_pool_size   = 0x40,

			ptr_sleep_handle = 0x08003291, -- UpdateSleep

			names = load_names("BE8E")
		},

		AE7E = {
			-- FE7U

			ptr_proc_forest  = 0x02026A30,
			proc_forest_size = 8,

			ptr_proc_pool    = 0, -- TODO
			proc_pool_size   = 0, -- TODO

			ptr_sleep_handle = -1, -- TODO

			names = load_names("AE7E")
		},

		AE7J = {
			-- FE7J

			ptr_proc_forest  = 0x02026A28,
			proc_forest_size = 8,

			ptr_proc_pool    = 0x02024E20,
			proc_pool_size   = 0x40,

			ptr_sleep_handle = -1, -- TODO

			names = load_names("AE7J")
		}
	},

	proc_instruction_formats = {
		[0x0000] = "END",
		[0x0001] = "NAME {narg}",
		[0x0002] = "CALL {larg}",
		[0x0003] = "SET_LOOP {larg}",
		[0x0004] = "SET_END {larg}",
		[0x0005] = "ADD_CHILD {larg}",
		[0x0006] = "ADD_CHILD_BLOCKING {larg}",
		[0x0007] = "<bugged instruction>",
		[0x0008] = "WAIT_FOR {larg}",
		[0x0009] = "END_ALL {larg}",
		[0x000A] = "BREAK_ALL_LOOP {larg}",
		[0x000B] = "LABEL {sarg}",
		[0x000C] = "GOTO {sarg}",
		[0x000D] = "JUMP {larg}",
		[0x000E] = "WAIT {sarg}",
		[0x000F] = "MARK {sarg}",
		[0x0010] = "HALT",
		[0x0011] = "UNIQUE_WEAK",
		[0x0012] = "???",
		[0x0013] = "NOP",
		[0x0014] = "WHILE {larg}",
		[0x0015] = "NOP2",
		[0x0016] = "CALL2 {larg}",
		[0x0017] = "UNIQUE_STRONG",
		[0x0018] = "CALL3 {larg}({sarg})",
		[0x0019] = "NOP3",
        
        -- aw2 exclusive below 
        [0x001A] = "unk1A",
        [0x001B] = "unk1B",
        [0x001C] = "unk1C",
        [0x001D] = "unk1D",
        [0x001E] = "unk1E",
        [0x001F] = "unk1F",
        [0x0020] = "unk20",
        [0x0021] = "unk21",
        [0x0022] = "unk22",
        [0x0023] = "unk23",
        [0x0024] = "unk24",
        [0x0025] = "Fade to white",
        [0x0026] = "Fade from white",
        [0x0027] = "unk27",
        [0x0028] = "unk28",
        [0x0029] = "unk29",
        [0x002A] = "unk2A",
        [0x002B] = "unk2B",
	},
	
	get_reference = function()
		return proc.references[gba.game_code]
	end,

	-- opcode => {mnemonic, field layout}
	-- field layout: "none" | "ptr" | "arg" | "both" | "sleep" (based on proc.h macro defs;
	-- opcodes with no confirmed layout fall back to "both" so no data is hidden)
	instruction_defs = {
		[0x00] = {"PROC_END", "none"},
		[0x01] = {"PROC_NAME", "ptr"},
		[0x02] = {"PROC_CALL", "ptr"},
		[0x03] = {"PROC_REPEAT", "ptr"},
		[0x04] = {"PROC_SET_END_CB", "ptr"},
		[0x05] = {"PROC_START_CHILD", "ptr"},
		[0x06] = {"PROC_START_CHILD_BLOCKING", "ptr"},
		[0x07] = {"PROC_START_MAIN", "both"},
		[0x08] = {"PROC_WHILE_EXISTS", "ptr"},
		[0x09] = {"PROC_END_EACH", "ptr"},
		[0x0A] = {"PROC_BREAK_EACH", "ptr"},
		[0x0B] = {"PROC_LABEL", "arg"},
		[0x0C] = {"PROC_GOTO", "arg"},
		[0x0D] = {"PROC_JUMP", "ptr"},
		[0x0E] = {"PROC_SLEEP", "sleep"},
		[0x0F] = {"PROC_MARK", "arg"},
		[0x10] = {"PROC_BLOCK", "none"},
		[0x11] = {"PROC_END_IF_DUPLICATE", "none"},
		[0x12] = {"PROC_12", "none"},
		[0x13] = {"PROC_13", "none"},
		[0x14] = {"PROC_WHILE", "ptr"},
		[0x15] = {"PROC_15", "none"},
		[0x16] = {"PROC_CALL_2", "ptr"},
		[0x17] = {"PROC_END_DUPLICATES", "none"},
		[0x18] = {"PROC_CALL_ARG", "both"},
		[0x19] = {"PROC_19", "none"},
		[0x1A] = {"PROC_1A", "both"},
		[0x1B] = {"PROC_1B", "arg"},
		[0x1C] = {"PROC_1C", "both"},
		[0x1D] = {"PROC_1D", "arg"},
		[0x1E] = {"PROC_1E", "arg"},
		[0x25] = {"PROC_FADE_TO_WHITE", "arg"},
		[0x26] = {"PROC_FADE_FROM_WHITE", "arg"},
		[0x29] = {"PROC_29", "arg"},
		[0x2A] = {"PROC_2A", "none"},
	},

	-- opcodes after which the real interpreter stops reading the script linearly
	-- (PROC_JUMP/0x0D isn't included here - it's followed to its target instead of stopping)
	ends_script = function(opc)
		return opc == 0x00 or opc == 0x10
	end,

	symbol_for = function(address)
		local name = proc.get_reference().names[address]

		if name ~= nil then
			return name
		end

		return string.format("0x%08X", address)
	end,

	format_instruction = function(opc, arg, ptr)
		local def = proc.instruction_defs[opc]
		local mnemonic, fields

		if def ~= nil then
			mnemonic, fields = def[1], def[2]
		else
			mnemonic, fields = string.format("PROC_%02X", opc), "both"
		end

		if fields == "none" then
			return mnemonic
		elseif fields == "ptr" then
			return string.format("%s(%s)", mnemonic, proc.symbol_for(ptr))
		elseif fields == "arg" then
			return string.format("%s(%d)", mnemonic, arg)
		elseif fields == "sleep" then
			if arg == 0 then
				return "PROC_YIELD"
			else
				return string.format("PROC_SLEEP(%d)", arg)
			end
		else -- "both"
			return string.format("%s(%s, %d)", mnemonic, proc.symbol_for(ptr), arg)
		end
	end,

	-- reads raw 8-byte proc instructions starting at `address` until a
	-- terminating opcode (END/BLOCK) or `max_instructions` is hit.
	-- PROC_JUMP doesn't stop the listing - it continues from the jump target,
	-- same as the real interpreter would.
	-- returns a list of {address, opcode, arg, ptr, text} entries.
	disassemble_script = function(address, max_instructions)
		local instructions = {}
		local addr = address

		for i = 1, max_instructions do
			local opc = memory.readshort(addr)
			local arg = memory.readshort(addr + 2)
			local ptr = memory.readlong(addr + 4)

			table.insert(instructions, {
				address = addr,
				opcode = opc,
				arg = arg,
				ptr = ptr,
				text = proc.format_instruction(opc, arg, ptr),
			})

			if opc == 0x0D then
				addr = ptr
			else
				addr = addr + 8

				if proc.ends_script(opc) then
					break
				end
			end
		end

		return instructions
	end,

	-- true while this proc's execution is blocked (proc_lockCnt != 0), most
	-- commonly because a PROC_START_CHILD_BLOCKING child of it hasn't ended yet.
	-- while blocked, the real interpreter runs neither this proc's script nor
	-- its idle callback for the frame.
	proc_is_blocked = function(pointer)
		return memory.readbyte(pointer+0x28) ~= 0
	end,

	-- proc_idleCb: non-zero while script execution is parked on something other
	-- than the normal instruction stream - either a PROC_REPEAT target (called
	-- directly every frame instead of stepping proc_scrUnk) or a sleep countdown.
	proc_get_idle_cb = function(pointer)
		return memory.readlong(pointer+0x10)
	end,

	-- true while proc_scrUnk is parked on a PROC_BLOCK instruction: ProcCmd_Block
	-- always returns FALSE without ever advancing the cursor, so once a proc
	-- reaches one it's stuck there permanently (until something external, e.g. a
	-- SetEndFunc callback, ends or redirects it) - not "actively" running.
	proc_is_stuck_at_block = function(pointer)
		if proc.proc_get_idle_cb(pointer) ~= 0 then
			return false -- parked on a repeat/sleep callback instead, not on the raw script
		end

		return memory.readshort(proc.proc_get_current_code_ptr(pointer)) == 0x10
	end,

	-- true if this proc should be treated as inactive for display purposes:
	-- genuinely blocked (proc_lockCnt != 0), or permanently stuck on PROC_BLOCK
	proc_is_inactive = function(pointer)
		return proc.proc_is_blocked(pointer) or proc.proc_is_stuck_at_block(pointer)
	end,

	-- finds which disassembled instruction (from disassemble_script) is the one
	-- actually executing every frame for this proc, if any:
	--  - if idle callback is a PROC_REPEAT target in this script, that PROC_REPEAT
	--  - otherwise, whichever instruction proc_scrUnk currently points to (covers
	--    manual LABEL/GOTO loops and plain in-progress scripts alike)
	proc_get_active_instruction_index = function(pointer, instructions)
		local idle_cb = proc.proc_get_idle_cb(pointer)

		if idle_cb ~= 0 then
			for i, instr in ipairs(instructions) do
				if instr.opcode == 0x03 and instr.ptr == idle_cb then
					return i
				end
			end

			return nil
		end

		local current = proc.proc_get_current_code_ptr(pointer)

		for i, instr in ipairs(instructions) do
			if instr.address == current then
				return i
			end
		end

		return nil
	end,
	
	get_proc = function(index)
		if index < 0 or index >= proc.get_reference().proc_pool_size then
			return nil
		end
		
		return proc.get_reference().ptr_proc_pool + (0x6C * index)
	end,

	
	proc_is_halted = function(pointer)
		return memory.readbyte(pointer+0x24) ~= 0 -- in aw2, +0x28 isn't set during sleep 
	end,
	
	proc_get_halt_count = function(pointer)
		return memory.readbyte(pointer+0x24) -- in aw2, +0x28 isn't set during sleep 
	end,
	
	proc_is_sleeping = function(pointer)
		return memory.readlong(pointer+0x0C) == proc.get_reference().ptr_sleep_handle
	end,
	
	proc_get_sleep_time = function(pointer)
		return memory.readshort(pointer+0x24)
	end,
	
	proc_get_start_code_ptr = function(pointer)
		return memory.readlong(pointer+0x00)
	end,
	
	proc_get_current_script_ptr = function(pointer)
		return memory.readlong(pointer+0x04)
	end,
    
	proc_get_current_code_ptr = function(pointer)
		return memory.readlong(pointer+0x08) -- +0x08 in aw2, +0x04 is usually but not always proc_Script / +0x00 
	end, -- r0=0x849e818 - after war room, wrong name 
	
    
    proc_get_name = function(pointer)
		local current_script = proc.proc_get_current_script_ptr(pointer)

		if current_script ~= 0 then
			return current_script
		end

		return proc.proc_get_start_code_ptr(pointer)
    end, 
    
	
	proc_read_name = function(pointer)
		local name = proc.get_reference().names[proc.proc_get_start_code_ptr(pointer)]

		if name == nil then
			name = proc.get_reference().names[proc.proc_get_name(pointer)]
		end
		
		if name ~= nil then
			return name
		else
			local nameptr = memory.readlong(pointer+0x10)
			
            
            if gba.game_code == "AW2E" then 
                return "--" 
            end 
            
			if nameptr ~= 0 then
				return gba.read_cstring(nameptr)
			else
				return "----"
			end
		end
	end,
    
	proc_get_state_summary = function(pointer)
		local code_start   = proc.proc_get_name(pointer)
		local code_current = proc.proc_get_current_code_ptr(pointer)
		
		local activity_str = (function()
			if proc.proc_is_halted(pointer) then
				return "H:" .. proc.proc_get_halt_count(pointer)
			end
			
			if proc.proc_is_sleeping(pointer) then
				return "S:" .. proc.proc_get_sleep_time(pointer)
			end
			
			return "-"
		end)()
		
        local code_diff = (code_current - code_start)

		if code_diff < 0 then
			code_start = proc.proc_get_start_code_ptr(pointer)
			code_diff = code_current - code_start
		end
        
		return string.format("%X+%X (%s)", code_start, code_diff, activity_str)
	end,
	
	proc_get_next = function(pointer)
		return memory.readlong(pointer+0x20)
	end,

	proc_get_prev = function(pointer)
		return memory.readlong(pointer+0x1C)
	end,

	proc_get_parent = function(pointer)
		return memory.readlong(pointer+0x14)
	end,
	
	proc_get_child = function(pointer)
		return memory.readlong(pointer+0x18)
	end,

	proc_is_allocated = function(pointer)
		return pointer ~= 0 and proc.proc_get_start_code_ptr(pointer) ~= 0
	end,

	proc_find_tree_root = function(tree)
		local candidate = 0

		for i = 0, proc.get_reference().proc_pool_size - 1 do
			local pointer = proc.get_proc(i)

			if proc.proc_is_allocated(pointer) and proc.proc_get_parent(pointer) == tree then
				candidate = pointer
			end
		end

		return candidate
	end,
	
	tree_iterator = function()
		return function(size, n)
			if n < size then
				n = n+1
				local pointer = memory.readlong(proc.get_reference().ptr_proc_forest + 4*n)

				if pointer == 0 then
					pointer = proc.proc_find_tree_root(n)
				end

				return n, pointer
			end
		end, proc.get_reference().proc_forest_size, (-1)
	end,
	
	proc_iterator = function(pointer)
		while pointer ~= 0 and proc.proc_get_prev(pointer) ~= 0 do
			pointer = proc.proc_get_prev(pointer)
		end

		return function(state)
			if state.count >= proc.get_reference().proc_pool_size or state.next == 0 then
				return nil
			end

			local result = state.next
			state.next = proc.proc_get_next(result)
			state.count = state.count + 1

			return result
		end, { next = pointer, count = 0 }, nil
	end,

	pool_iterator = function()
		return function(state)
			while state.index < proc.get_reference().proc_pool_size do
				local pointer = proc.get_proc(state.index)
				state.index = state.index + 1

				if proc.proc_is_allocated(pointer) then
					return pointer
				end
			end
		end, { index = 0 }, nil
	end,
	
	child_iterator = function(pointer)
		return proc.proc_iterator(proc.proc_get_child(pointer))
	end
}
