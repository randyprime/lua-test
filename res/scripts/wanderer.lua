-- Wanderer Entity
-- Wanders left and right, changing direction periodically
-- SAVE/LOAD TEST: Tests timer countdown and discrete state changes

local entity = {
    -- Custom data fields that get saved/loaded
    wander_speed = 50,
    wander_dir = 1,            -- current direction: 1 or -1
    change_dir_timer = 0,      -- counts down to direction change
    change_dir_interval = 2.0, -- seconds between direction changes
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

