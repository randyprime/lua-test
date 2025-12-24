-- Player Follower Entity
-- Follows the player's input but moves slower

local entity = {
    -- Custom data fields
    follow_speed = 30,
}

function entity:update(dt)
    -- Get input
    local input = get_input_vector()
    
    -- Get current position
    local pos = get_pos()
    
    -- Move based on input
    local new_x = pos.x + input.x * self.follow_speed * dt
    local new_y = pos.y + input.y * self.follow_speed * dt
    set_pos(new_x, new_y)
    
    -- Flip based on input direction
    if input.x ~= 0 then
        set_flip_x(input.x < 0)
    end
    
    -- Animate based on whether moving
    if input.x ~= 0 or input.y ~= 0 then
        set_animation("player_run", 0.1, true)
    else
        set_animation("player_idle", 0.3, true)
    end
end

return entity

