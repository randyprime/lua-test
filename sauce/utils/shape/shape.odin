package shape

import "core:log"
import "core:math"
import "core:math/linalg"

import utils "../"

rect_get_center :: proc(a: Vec4) -> Vec2 {
	min := a.xy;
	max := a.zw;
	return { min.x + 0.5 * (max.x-min.x), min.y + 0.5 * (max.y-min.y) };
}

rect_make_with_pos :: proc(pos: Vec2, size: Vec2, pivot:= utils.Pivot.bottom_left) -> Vec4 {
	rect := (Vec4){0,0,size.x,size.y};
	rect = rect_shift(rect, pos - utils.scale_from_pivot(pivot) * size);
	return rect;
}
rect_make_with_size :: proc(size: Vec2, pivot: utils.Pivot) -> Vec4 {
	return rect_make({}, size, pivot);
}

rect_make :: proc{
	rect_make_with_pos,
	rect_make_with_size,
}

rect_shift :: proc(rect: Vec4, amount: Vec2) -> Vec4 {
	return {rect.x + amount.x, rect.y + amount.y, rect.z + amount.x, rect.w + amount.y};
}

rect_size :: proc(rect: Rect) -> Vec2 {
	return { abs(rect.x - rect.z), abs(rect.y - rect.w) }
}

rect_multiply_matrix :: proc(rect: Rect, m: linalg.Matrix4f32) -> Rect {
	rect := rect
	rect.xy = (Vec4{rect.x, rect.y, 0, 1} * m).xy
	rect.zw = (Vec4{rect.z, rect.w, 0, 1} * m).xy
	return rect
}

rect_correct :: proc(rect: Rect) -> Rect {
	result := rect
	if result.x > result.z do utils.swap(&result.x, &result.z);
	if result.y > result.w do utils.swap(&result.y, &result.w);
	return result;
}

rect_scale :: proc(_rect: Rect, scale: f32) -> Rect {
	rect := _rect
	origin := rect.xy
	rect = rect_shift(rect, -origin)
	scale_amount := (rect.zw * scale)-rect.zw
	rect.xy -= scale_amount / 2
	rect.zw += scale_amount / 2
	rect = rect_shift(rect, origin)
	return rect
}

rect_scale_v2 :: proc(_rect: Rect, scale: Vec2) -> Rect {
	rect := _rect
	origin := rect.xy
	rect = rect_shift(rect, -origin)
	
	// Calculate scale amount for each axis separately
	scale_amount := (rect.zw * scale) - rect.zw
	
	// Adjust rectangle while maintaining center position
	rect.xy -= scale_amount / 2
	rect.zw += scale_amount / 2
	
	rect = rect_shift(rect, origin)
	return rect
}

rect_rotate :: proc(rect: Rect, angle_degrees: f32) -> Rect {
	// Get center and calculate corners
	center := rect_get_center(rect)
	size := rect_size(rect)
	half_size := size / 2
	
	// Four corners relative to center
	corners := [4]Vec2{
		{-half_size.x, -half_size.y},
		{ half_size.x, -half_size.y},
		{ half_size.x,  half_size.y},
		{-half_size.x,  half_size.y},
	}
	
	// Convert angle to radians and get sin/cos
	angle_rad := math.to_radians(angle_degrees)
	cos_a := math.cos(angle_rad)
	sin_a := math.sin(angle_rad)
	
	// Find bounding box of rotated corners
	min_x := f32(max(f32))
	max_x := f32(min(f32))
	min_y := f32(max(f32))
	max_y := f32(min(f32))
	
	for corner in corners {
		// Rotate corner around origin
		rotated := Vec2{
			corner.x * cos_a - corner.y * sin_a,
			corner.x * sin_a + corner.y * cos_a,
		}
		// Translate back to world space
		rotated += center
		
		// Update bounding box
		min_x = min(min_x, rotated.x)
		max_x = max(max_x, rotated.x)
		min_y = min(min_y, rotated.y)
		max_y = max(max_y, rotated.y)
	}
	
	return {min_x, min_y, max_x, max_y}
}

rect_expand :: proc(rect: Rect, amount: f32) -> Rect {{
	rect := rect
	rect.xy -= amount
	rect.zw += amount
	return rect
}}

circle_shift :: proc(circle: Circle, amount: Vec2) -> Circle {
  circle := circle
  circle.pos += amount
  return circle
}

shift :: proc(s: Shape, amount: Vec2) -> Shape {
	if s == {} || amount == {} {
		return s
	}

  switch shape in s {
    case Rect: return rect_shift(shape, amount)
    case Circle: return circle_shift(shape, amount)
    case: {
      log.error("unsupported shape shift", s)
      return {}
    }
  }
}

get_center :: proc(s: Shape) -> Vec2 {
	#partial switch shape in s {
    case Rect: return rect_get_center(shape)
    case: {
      log.error("unsupported shape shift", s)
      return {}
    }
  }
}