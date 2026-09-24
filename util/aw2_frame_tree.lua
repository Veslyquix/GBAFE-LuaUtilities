-- Per-frame call tree for AW2E (AW2U), transcribed from the aw2bhr decomp.
--
-- The root/aux hooks at 0x030040D0 / 0x030040EC are called once per frame.
-- While gUnknown_03003F3C == 1 the aux hook sub_080369BC runs MapMainIdle,
-- a state machine on gUnknown_030032D8 whose handlers are themselves state
-- machines - so, unlike during menus, most of the interesting per-frame work
-- happens outside of the proc trees.
--
-- Node fields (all optional except name):
--   name       function name as it appears in the decomp
--   note       short description shown after the name
--   when       function() -> ok, detail. ok: true = runs, false = skipped
--              this frame, nil = can't tell from RAM. detail is shown inline.
--   switch     { label = "var", read = function() -> value, cases = {[v] = node} }
--              only the case matching the current value is expanded
--   children   list of nodes, or function() -> list of nodes
--   proc_tree  gProcTreeRootArray index run by Proc_Run here
--   keep       true to keep a plain call visible when leaf calls are hidden
--
-- Values are read after the frame has finished, so a switch shows the case
-- that will run on the *next* frame. One-shot transition states (e.g. MapMainIdle
-- states 2, 5, 7..12) are usually only visible for a single frame.

local function read_s8(address)
	local value = memory.readbyte(address)
	if value >= 0x80 then value = value - 0x100 end
	return value
end

local function read_s16(address)
	local value = memory.readshort(address)
	if value >= 0x8000 then value = value - 0x10000 end
	return value
end

local addr = {
	map_main_enable  = 0x03003F3C, -- gUnknown_03003F3C: 1 => sub_080369BC calls MapMainIdle
	game_lock        = 0x030030F0, -- gGameLock { s8 map; u8 unitSelection; u8 mainMenu; }
	map_state        = 0x030032D8, -- gUnknown_030032D8: MapMainIdle state
	map_state_parked = 0x030044DC, -- gUnknown_030044DC: state restored by case 16
	map_block        = 0x030040E4, -- gUnknown_030040E4: also stops MapMainIdle dispatch
	player_state     = 0x03003334, -- gUnknown_03003334: player phase (sub_0802DC2C) state
	ai_state         = 0x03004780, -- gUnknown_03004780: AI phase (sub_0806171C) state
	ai_step          = 0x03004770, -- gUnknown_03004770: index into the AI step tables
	ai_sub_state     = 0x030045D4, -- gUnknown_030045D4: sub_0805FD64 state
	remote_state     = 0x03003F60, -- gUnknown_03003F60: sub_08034350 state
	play_st          = 0x03003FC0, -- gPlaySt
	busy_slots       = 0x0200C528, -- gUnknown_0200C528[10], stride 0x18 (sub_08019260)
	ai_steps_clear   = 0x085766E8, -- gUnknown_085766E8: AI step table, no fog
	ai_steps_fog     = 0x08576738, -- gUnknown_08576738: AI step table, fog
	phase_done       = 0x03004094,
	frame_mask       = 0x030043F4,
	clock            = 0x03004008,
}

local function map_main_enabled()
	return memory.readlong(addr.map_main_enable) == 1
end

-- sub_08019260: TRUE while any of the 10 slots at gUnknown_0200C528 is in use
local function busy_slots_in_use()
	for i = 0, 9 do
		if memory.readlong(addr.busy_slots + i * 0x18) ~= 0 then
			return true
		end
	end
	return false
end

local function not_busy()
	if busy_slots_in_use() then
		return false, "sub_08019260 busy"
	end
	return true
end

local function symbol(ptr)
	local normalized = ptr - (ptr % 2)
	local name = proc.get_reference().names[normalized] or proc.get_reference().names[ptr]
	return name or string.format("sub_%08X", normalized)
end

local function leaf(name, note)
	return { name = name, note = note }
end

local function proc_run(tree)
	return { name = "Proc_Run", proc_tree = tree }
end

-- sub_0805FD64: shared by the AI phase (state 3) and sub_080343D8
local sub_0805FD64 = {
	name = "sub_0805FD64",
	switch = {
		label = "gUnknown_030045D4",
		read = function() return read_s16(addr.ai_sub_state) end,
		cases = {
			[0]  = leaf("sub_0805FE0C"),
			[1]  = leaf("sub_0805FF64"),
			[2]  = leaf("sub_0805FFA0"),
			[3]  = leaf("sub_08060424"),
			[4]  = leaf("sub_0806044C"),
			[5]  = leaf("sub_08060474"),
			[6]  = leaf("sub_080604A4"),
			[7]  = leaf("sub_08060324"),
			[8]  = leaf("sub_08060384"),
			[9]  = leaf("sub_080603D4"),
			[10] = leaf("sub_0806050C"),
			[11] = leaf("sub_08060554"),
		},
	},
}

local player_phase = {
	name = "sub_0802DC2C",
	note = "player phase",
	switch = {
		label = "gUnknown_03003334",
		read = function() return memory.readshort(addr.player_state) end,
		cases = {
			[0] = { name = "sub_0802DCB4", note = "free cursor", children = {
				leaf("sub_08023824"), leaf("sub_0802361C"), leaf("sub_08023908"), leaf("sub_08023274"),
				leaf("sub_0802DBF8", "input gate"),
				leaf("sub_0802A7C4"), leaf("sub_0802776C"),
			} },
			[1] = { name = "sub_0802DE1C", note = "pick move target", children = {
				leaf("sub_08023824"), leaf("sub_080236E8"), leaf("sub_08023908"), leaf("sub_08023274"),
				leaf("sub_08039264"), leaf("sub_0802DBF8", "input gate"),
			} },
			[2] = { name = "sub_0802DEFC", note = "pick own unit", children = {
				leaf("sub_08023824"), leaf("sub_0802361C"), leaf("sub_08023908"), leaf("sub_08023274"),
				leaf("sub_0802DBF8", "input gate"),
			} },
			[3] = { name = "sub_0802E698", children = { leaf("sub_08022AAC"), leaf("sub_0802D558") } },
			[4] = { name = "sub_0802E6C0", when = function()
				local locked = memory.readbyte(addr.game_lock + 1)
				return true, string.format("unitSelLock %d", locked)
			end },
			[5] = { name = "sub_0802E6F8", children = { leaf("sub_08022AAC"), leaf("LockUnitSelection"), leaf("sub_080424FC") } },
			[6] = { name = "sub_0802DFC8", note = "until B released", children = {
				leaf("sub_08023824"), leaf("sub_080236E8"), leaf("sub_08023908"), leaf("sub_08023274"),
			} },
			[7] = { name = "sub_0802E260", children = {
				leaf("sub_08023824"), leaf("sub_08023518"), leaf("sub_08023908"), leaf("sub_0802DBF8"),
			} },
			[8] = { name = "sub_0802E278", note = "until B released", children = {
				leaf("sub_08023824"), leaf("sub_08023518"), leaf("sub_08023908"), leaf("sub_0802DBF8", "input gate"),
			} },
		},
	},
}

local ai_phase = {
	name = "sub_0806171C",
	note = "AI phase",
	when = not_busy,
	switch = {
		label = "gUnknown_03004780",
		read = function() return read_s16(addr.ai_state) end,
		cases = {
			[0] = { name = "RunAiTurn", note = "plan turn" },
			[1] = {
				name = "sub_08061B00",
				note = "AI step",
				children = function()
					local fog = memory.readbyte(addr.play_st + 0x0D) ~= 0
					local table_addr = fog and addr.ai_steps_fog or addr.ai_steps_clear
					local step = memory.readlong(addr.ai_step)
					local ptr = memory.readlong(table_addr + 4 * step)

					return { {
						name = symbol(ptr),
						note = string.format("%s[%d]", fog and "gUnknown_08576738" or "gUnknown_085766E8", step),
						keep = true,
					} }
				end,
			},
			[2] = leaf("sub_0805D438"),
			[3] = sub_0805FD64,
			[4] = { name = "sub_08061AC4", note = "end turn", when = function()
				if memory.readbyte(0x030044D8) == 1 then
					return false, "gUnknown_030044D8 == 1"
				end
				return true
			end },
			[5] = { name = "sub_080606D0", note = "build units" },
		},
	},
}

local map_main_idle = {
	name = "MapMainIdle",
	when = function()
		if not map_main_enabled() then
			return false, string.format("gUnknown_03003F3C = %d", memory.readlong(addr.map_main_enable))
		end
		return true
	end,
	children = {
		{
			name = "dispatch",
			when = function()
				local lock = read_s8(addr.game_lock)
				local block = read_s16(addr.map_block)

				if lock ~= 0 then
					return false, string.format("map lock %d", lock)
				end

				if block ~= 0 then
					return false, string.format("gUnknown_030040E4 = %d", block)
				end

				return true
			end,
			switch = {
				label = "gUnknown_030032D8",
				read = function() return memory.readshort(addr.map_state) end,
				cases = {
					[1]  = { name = "sub_08034938", note = "turn limit check" },
					[2]  = { name = "sub_080349E4", note = "turn start" },
					[3]  = { name = "sub_08034AF8", note = "turn banner" },
					[4]  = { name = "sub_08034DB0", note = "wait sub_0803B628" },
					[5]  = leaf("sub_08034DCC"),
					[6]  = { name = "sub_08034DF8", when = not_busy },
					[7]  = leaf("sub_08034EA4"),
					[8]  = leaf("sub_08034C90"),
					[9]  = leaf("sub_08034CA4"),
					[10] = leaf("sub_08034CB8"),
					[11] = { name = "sub_08034CD4", when = function()
						local map_id = memory.readbyte(addr.play_st + 0x02)
						if map_id == 0x8A or map_id == 0x8B or map_id == 0x8D or map_id == 0x8F then
							return true
						end
						return not_busy()
					end },
					[12] = { name = "sub_08034D18", note = "pick controller" },
					[13] = player_phase,
					[14] = ai_phase,
					[16] = { name = "sub_08034ED0", note = "restore parked state" },
					[18] = { name = "sub_08034EF0", when = not_busy },
					[19] = {
						name = "sub_08034350",
						switch = {
							label = "gUnknown_03003F60",
							read = function() return memory.readshort(addr.remote_state) end,
							cases = {
								[0] = { name = "sub_08034394", children = { leaf("sub_08034598") } },
								[4] = { name = "sub_080343D8", children = { leaf("sub_08034598"), sub_0805FD64 } },
							},
						},
					},
					[20] = leaf("sub_08034F1C"),
				},
			},
		},
		{
			name = "sub_0802776C(3)",
			when = function()
				local state = memory.readshort(addr.map_state)
				local parked = memory.readshort(addr.map_state_parked)

				if state ~= 14 and parked ~= 14 then
					return false
				end

				if read_s8(addr.game_lock) == 0 then
					return true
				end

				return nil, "if Proc_Find(gUnknown_0849A00C)"
			end,
		},
	},
}

local function phase_flush(extra)
	local children = {
		leaf("sub_0801F0E0"), leaf("sub_080128D0"), leaf("sub_08011FF0"), leaf("sub_08013B2C"), leaf("sub_08011AD8"),
	}

	if extra ~= nil then
		table.insert(children, leaf(extra))
	end

	-- gUnknown_03004094 is flipped back and forth between the two hooks, so its value after the frame says nothing about this branch
	return { name = "if gUnknown_03004094", note = "aux done", when = function() return nil end, children = children }
end

local function frame_mask_detail()
	local mask = memory.readshort(addr.frame_mask)

	if mask == 0 then
		return true
	end

	return true, string.format("every %d frames", mask + 1)
end

local function main_hook(name, extra)
	return {
		name = name,
		children = {
			leaf("sub_0803B3F8"), leaf("sub_0802FACC"), proc_run(0), leaf("sub_08011B98"),
			leaf("sub_0801F0AC"), leaf("sub_0801F0C8"), phase_flush(extra), leaf("sub_0801F0FC"), leaf("sub_0803B408"),
		},
	}
end

aw2_frame_tree = {
	is_active = function()
		return gba.game_code == "AW2E" and map_main_enabled()
	end,

	hook_addresses = {
		{ label = "main", address = 0x030040D0 },
		{ label = "aux",  address = 0x030040EC },
	},

	-- keyed by (even) hook address
	hooks = {
		[0x08036884] = main_hook("sub_08036884"),
		[0x08036944] = main_hook("sub_08036944"),
		[0x08036A50] = main_hook("sub_08036A50", "sub_0801F050"),

		[0x080368E8] = { name = "sub_080368E8", children = {
			leaf("sub_0801F050"), leaf("sub_08013510"), leaf("sub_08054B7C"), leaf("sub_08019470"), leaf("sub_08015954"),
			proc_run(1), proc_run(2), proc_run(3), proc_run(5), proc_run(4),
			leaf("sub_0801F06C"), leaf("sub_0801F084"), leaf("sub_0803B404"),
		} },

		[0x080369BC] = { name = "sub_080369BC", when = frame_mask_detail, children = {
			leaf("sub_0801F050"), leaf("sub_08013510"), leaf("sub_08054B7C"), leaf("sub_08019470"),
			map_main_idle,
			leaf("sub_08015954"),
			proc_run(1), proc_run(2), proc_run(3), proc_run(5), proc_run(4),
			leaf("sub_08023EEC"), leaf("sub_0803F990"),
			leaf("sub_0801F06C"), leaf("sub_0801F084"), leaf("sub_0803B404"),
		} },

		[0x08036AB8] = { name = "sub_08036AB8", when = frame_mask_detail, children = {
			leaf("sub_08013510"), leaf("sub_08054B7C"), leaf("sub_08019470"),
			proc_run(1), proc_run(2), proc_run(3),
			leaf("sub_08015954"),
			proc_run(5), proc_run(4),
			leaf("sub_0801F06C"), leaf("sub_0801F084"), leaf("sub_0803B404"),
		} },
	},
}
