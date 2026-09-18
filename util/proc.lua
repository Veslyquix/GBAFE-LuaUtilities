require "util/gba"

proc = {
	references = {
        AW2E = { -- AW2U (see rom header + 0xAC) 
        -- [849EB7C..849EB84]? -- break point on known proc data read on new campaign 
        -- 1c8f4 proc start? r0 ProcPtr, r1 root tree -- went to r14 a couple times? 
            -- calls 1d264 
            -- 200E414 points to sProcArray
            ptr_proc_pool = 0x200E390,  
            proc_pool_size = 0x21, -- maybe? since 0x200e414 is 0x84 bytes away divided by 4 
        -- [200e390]! hits 0x801C878 which seems to be ProcInit 
        -- 200e410, 200e414, 200e418,  
        -- 200e414 is sProcAllocListHead maybe? 
        -- 200e418 - 200e434 is gProcTreeRootArray
            ptr_proc_forest = 0x200e418, 
            proc_forest_size = 8, 
        -- [84C3138+0x40..84C3138+0x47]? // 8th entry in LoadBattleMap proc at 0x084C3138 
        -- hits 0x801CFC8 as InitSleep 
        -- [200d6e8+0x24]? ProcRam+0x24 as sleep timer 
        -- hits 0x801CFAC as UpdateSleep  
            ptr_sleep_handle = 0x801cfad, 
			names = {
                [0x08580F24] = "Intro A", 
				[0x08581500] = "Intro B",
				[0x08581C68] = "Title A",
				[0x08581CF8] = "Title B",
				[0x0849e818] = "Main Menu",
				[0x0849EB34] = "Campaign",
				[0x08616FD4] = "Campaign Intro",
				[0x0848A140] = "Dialogue",
				[0x08614460] = "WM Listener",
				[0x08614390] = "WM_MoveScope",
				[0x08614370] = "WM_DrawDifficultyStars",
				[0x08615BBC] = "WM_ConfirmExit",
				[0x0849EC1C] = "War Room",
				[0x0849ECE0] = "Versus",
				[0x084C3138] = "Battle Maps",
				[0x0849EC8C] = "Link",
				[0x0849EA94] = "Design Room",
				[0x0849EAAC] = "Sound Room",
			}
        -- 
        
        }, 
		BE8E = {
			-- FE8U
			
			ptr_proc_forest  = 0x02026A70, -- gProcTreeRootArray
			proc_forest_size = 8,
			
			ptr_proc_pool    = 0x02024E68, -- sProcArray
			proc_pool_size   = 0x40,
			
			ptr_sleep_handle = 0x08003291, -- UpdateSleep
			
			names = {
			}
		},
		
		AE7E = {
			-- FE7U
			
			ptr_proc_forest  = 0x02026A30,
			proc_forest_size = 8,
			
			ptr_proc_pool    = 0, -- TODO
			proc_pool_size   = 0, -- TODO
			
			ptr_sleep_handle = -1, -- TODO
			
			names = {
				[0x8B924BC] = "Game Control",
				[0x8CE3C54] = "Main Menu Logic"
			}
		},
		
		AE7J = {
			-- FE7J
			
			ptr_proc_forest  = 0x02026A28,
			proc_forest_size = 8,
			
			ptr_proc_pool    = 0x02024E20,
			proc_pool_size   = 0x40,
			
			ptr_sleep_handle = -1, -- TODO
			
			names = {
				[0x8C01744] = "Game Control",
				[0x8C01DBC] = "Map Main Logic",
				[0x8C02630] = "Player Phase Logic",
				[0x8C02870] = "Move Range Gfx",
				[0x8C05464] = "[MAPTASK]",
				[0x8D64F4C] = "Moving Unit Gfx",
				[0x8DAD3A4] = "Main Menu Logic",
				[0x8C09BF4] = "Any Menu",
				[0x8C09C34] = "Menu Command",
				[0x8D8B2D8] = "Goal Box",
				[0x8D8B1A0] = "Terrain Box",
				[0x8D8B200] = "Minimug Box"
			}
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
	ends_script = function(opc)
		return opc == 0x00 or opc == 0x0D or opc == 0x10
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
	-- terminating opcode (END/JUMP/BLOCK) or `max_instructions` is hit
	disassemble_script = function(address, max_instructions)
		local lines = {}
		local addr = address

		for i = 1, max_instructions do
			local opc = memory.readshort(addr)
			local arg = memory.readshort(addr + 2)
			local ptr = memory.readlong(addr + 4)

			table.insert(lines, proc.format_instruction(opc, arg, ptr))

			addr = addr + 8

			if proc.ends_script(opc) then
				break
			end
		end

		return lines
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
	
	proc_get_start2_code_ptr = function(pointer)
		return memory.readlong(pointer+0x04)
	end,
    
	proc_get_current_code_ptr = function(pointer)
		return memory.readlong(pointer+0x08) -- +0x08 in aw2, +0x04 is usually but not always proc_Script / +0x00 
	end, -- r0=0x849e818 - after war room, wrong name 
	
    
    proc_get_name = function(pointer) 
		local code_start   = proc.proc_get_start_code_ptr(pointer)
		local code_current = proc.proc_get_current_code_ptr(pointer)
		local code_start2 = proc.proc_get_start2_code_ptr(pointer)
        local code_diff = (code_current - code_start)
        if code_diff < 0 then 
            code_start = code_start2
            code_diff = (code_current - code_start2) 
        end 
        return code_start 
    end, 
    
	
	proc_read_name = function(pointer)
		-- local name = proc.get_reference().names[memory.readlong(pointer)]
		local name = proc.get_reference().names[proc.proc_get_name(pointer)]
		
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
		local code_start   = proc.proc_get_start_code_ptr(pointer)
		local code_current = proc.proc_get_current_code_ptr(pointer)
		local code_start2 = proc.proc_get_start2_code_ptr(pointer)
		
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
            code_start = code_start2
            code_diff = (code_current - code_start2) 
        end 
        
		return string.format("%X+%X (%s)", code_start, code_diff, activity_str)
	end,
	
	proc_get_next = function(pointer)
		return memory.readlong(pointer+0x20)
	end,
	
	proc_get_child = function(pointer)
		return memory.readlong(pointer+0x18)
	end,
	
	tree_iterator = function()
		return function(size, n)
			if n < size then
				n = n+1
				return n, memory.readlong(proc.get_reference().ptr_proc_forest + 4*n)
			end
		end, proc.get_reference().proc_forest_size, (-1)
	end,
	
	proc_iterator = function(pointer)
		return function(state, value)
			if value == nil then
				if state ~= 0 then
					return state
				end
			else
				local result = proc.proc_get_next(value)
				
				if result ~= 0 then
					return result
				end
			end
		end, pointer, nil
	end,
	
	child_iterator = function(pointer)
		return proc.proc_iterator(proc.proc_get_child(pointer))
	end
}
