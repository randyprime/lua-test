-- Wanderer Entity
-- A simple entity that wanders back and forth

local entity = {
    -- Custom data fields
    wander_speed = 50,
    wander_dir = 1,
    change_dir_timer = 0,
    change_dir_interval = 2.0,
}

function entity:update(dt)
    -- Get current position
    local pos = get_pos()
    
    -- Update direction change timer
    self.change_dir_timer = self.change_dir_timer - dt
    if self.change_dir_timer <= 0 then
        -- Randomly change direction
        self.wander_dir = math.random() > 0.5 and 1 or -1
        self.change_dir_timer = self.change_dir_interval
    end
    
    -- Move entity
    local new_x = pos.x + self.wander_dir * self.wander_speed * dt
    set_pos(new_x, pos.y)
    
    -- Flip sprite based on direction
    set_flip_x(self.wander_dir < 0)
    
    -- Set animation
    set_animation("player_idle", 0.3, true)
end

return entity

