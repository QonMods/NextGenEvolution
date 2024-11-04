-- Set the default 'evolution due to pollution' factor for the 'default' preset to 0
data.raw['map-settings']['map-settings'].enemy_evolution.pollution_factor = 0

-- Set the default 'evolution due to pollution' factor for the all other presets to 0
for k, v in pairs(data.raw['map-gen-presets'].default) do
    if type(v) == 'table' and k ~= 'default' then
        v.advanced_settings = v.advanced_settings or {}
        v.advanced_settings.enemy_evolution = v.advanced_settings.enemy_evolution or {}
        v.advanced_settings.enemy_evolution.pollution_factor = 0
    end
end
