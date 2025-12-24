-- Player Entity
-- Main player character controlled by user input

local entity = {
    -- Custom data fields
    last_known_x_dir = 1,
}

function entity:init()
    -- This offset is to take it from the bottom center of the aseprite document
    -- and center it at the feet
    set_pos(0, 0) -- Default starting position
end

function entity:update(dt)
    -- Get input
    local input_dir = get_input_vector()
    
    -- Get current position
    local pos = get_pos()
    
    -- Move player
    local move_speed = 100.0
    local new_x = pos.x + input_dir.x * move_speed * dt
    local new_y = pos.y + input_dir.y * move_speed * dt
    set_pos(new_x, new_y)
    
    -- Track last known direction
    if input_dir.x ~= 0 then
        self.last_known_x_dir = input_dir.x
    end
    
    -- Flip sprite based on direction
    set_flip_x(self.last_known_x_dir < 0)
    
    -- Set animation based on movement
    if input_dir.x == 0 and input_dir.y == 0 then
        set_animation("player_idle", 0.3, true)
    else
        set_animation("player_run", 0.1, true)
    end
end

return entity

