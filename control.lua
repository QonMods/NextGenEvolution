-- Copyright (C) 2019  Qon

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>

local M10 = 10 * 1000 * 1000

-- Entity groups
local spawner = {'biter-spawner', 'spitter-spawner'}
local tree_dying = {'tree-dying-proxy'}
local nature = {'tree-proxy', 'tile-proxy'}
function trees(name) return string.find(name, 'tree') and true or false end
function natives(name) return (string.find(name, 'biter') or string.find(name, 'spitter')) and true or false end

local absorbers = {
    {slot = 'gogreen-spawner-absorb', entities = spawner, input = false},
    {slot = 'gogreen-dying-tree-absorb', entities = tree_dying, input = false},
    {slot = 'gogreen-nature-absorb', entities = nature, input = false},
}
local killed = {
    {slot = 'gogreen-nature-killed', entities = trees, input = true},
    {slot = 'gogreen-natives-killed', entities = natives, input = true},
}


function evo_combine(a, b)
    return 1 - (1 - a) * (1 - b)
end
function getstat(flow, entities, input, slot)
    if type(entities) ~= 'table' then
        -- When entities is a function: build the enitities array dynamically by filtering the killed stat with the function
        local io_side = input and 'input_counts' or 'output_counts'
        local t = {}
        for k, v in pairs(flow[io_side]) do
            if entities(k) then table.insert(t, k) end
        end
        entities = t
    end

    local value = 0
    for _, name in ipairs(entities) do
        value = value + flow.get_flow_count{name = name, input = input, precision_index = defines.flow_precision_index.one_minute, count = true}
    end
    return value
end

commands.add_command('ngevolution', 'Replacement evolution command that provides info when playing with Next Gen Evolution.', function(event)
    -- game.print(game.table_to_json(event))
    local p = game.players[event.player_index]
    local names = {
        evolution_factor_by_time = 'Time',
        evolution_factor_by_pollution = 'Pollution created',
        evolution_factor_by_killing_spawners = 'Spawners kills',
    }
    local stats = {
        evolution_factor_by_time = game.forces.enemy.evolution_factor_by_time,
        evolution_factor_by_pollution = game.forces.enemy.evolution_factor_by_pollution,
        evolution_factor_by_killing_spawners = game.forces.enemy.evolution_factor_by_killing_spawners
    }
    for _, v in pairs(absorbers) do
        stats[v.slot] = global.stats[v.slot]
    end
    for _, v in pairs(killed) do
        stats[v.slot] = global.stats[v.slot]
    end
    local sum = 0
    for _, v in pairs(stats) do
        sum = sum + v
    end
    local stats_pct = {}
    for k, v in pairs(stats) do
        stats_pct[k] = stats[k] / (sum or 1)
    end
    local s = {'', 'Evolution factor: '..game.forces.enemy.evolution_factor}
    for k, v in pairs(stats_pct) do
        table.insert(s, {'', ' (', string.match(k, 'gogreen') and {'mod-setting-name.'..k} or names[k], ' ',  ''..(math.floor(v * 100)), '%)'})
    end
    p.print(s)
end)

commands.add_command('nge_debug', 'debug command for Next Gen Evolution', function(event)
    -- game.print(game.table_to_json(event))
    local p = game.players[event.player_index]
    local stats = {
        evolution_factor_by_time = game.forces.enemy.evolution_factor_by_time,
        evolution_factor_by_pollution = game.forces.enemy.evolution_factor_by_pollution,
        evolution_factor_by_killing_spawners = game.forces.enemy.evolution_factor_by_killing_spawners
    }
    for _, v in pairs(absorbers) do
        stats[v.slot] = global.stats[v.slot]
    end
    for _, v in pairs(killed) do
        stats[v.slot] = global.stats[v.slot]
    end
    local sum = 0
    for _, v in pairs(stats) do
        sum = sum + v
    end
    p.print(serpent.block({stats, sum}))
end)

script.on_nth_tick(60*60, function(event)
    local ef = game.forces.enemy.evolution_factor

    for _, v in ipairs(absorbers) do
        if settings.global[v.slot].value ~= 0 then
            local effect = getstat(game.pollution_statistics, v.entities, v.input, v.slot) * settings.global[v.slot].value / M10
            global.stats[v.slot] = global.stats[v.slot] + effect
            ef = evo_combine(ef, effect)
        end
    end

    for k,f in pairs(game.forces) do
        if f ~= game.forces.enemy then
            for _, v in ipairs(killed) do
                if settings.global[v.slot].value ~= 0 then
                    local effect = getstat(f.kill_count_statistics, v.entities, v.input, v.slot) * settings.global[v.slot].value / M10
                    global.stats[v.slot] = global.stats[v.slot] + effect
                    ef = evo_combine(ef, effect)
                end
            end
        end
    end

    game.forces.enemy.evolution_factor = ef
end)

function init()
    global.stats = global.stats or {}
    for _, v in pairs(absorbers) do
        global.stats[v.slot] = global.stats[v.slot] or 0
    end
    for _, v in pairs(killed) do
        global.stats[v.slot] = global.stats[v.slot] or 0
    end
end

script.on_init(init)

script.on_configuration_changed(function(event)
    local cmc = event.mod_changes[script.mod_name]
    if cmc and cmc.old_version ~= cmc.new_version then
        init()
    end
end)