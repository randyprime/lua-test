-- Spinner Entity
-- An entity that spins in place

local entity = {
    -- Custom data fields
    spin_speed = 2.0,  -- radians per second
    bob_speed = 1.0,
    bob_amount = 10.0,
    start_y = 0,
    time = 0,
}

function entity:update(dt)
    -- Get current position
    local pos = get_pos()
    
    -- Initialize start_y on first frame
    if self.start_y == 0 then
        self.start_y = pos.y
    end
    
    -- Update time
    self.time = self.time + dt
    
    -- Spin
    local current_rotation = get_rotation()
    set_rotation(current_rotation + self.spin_speed * dt)
    
    -- Bob up and down
    local bob_offset = math.sin(self.time * self.bob_speed) * self.bob_amount
    set_pos(pos.x, self.start_y + bob_offset)
    
    -- Set animation
    set_animation("player_still", 0.2, true)
end

return entity

