use macroquad::prelude::*;

#[macroquad::main("Centered Vortex")]
async fn main() {
    let mut angle_offset = 0.0;

    loop {
        clear_background(BLACK);

        let screen_cx = screen_width() / 2.0;
        let screen_cy = screen_height() / 2.0;

        let grid_spacing = 20.0;
        let max_radius = 240.0;

        for y in (0..screen_height() as i32).step_by(grid_spacing as usize) {
            for x in (0..screen_width() as i32).step_by(grid_spacing as usize) {
                let fx = x as f32;
                let fy = y as f32;

                let dx = fx - screen_cx;
                let dy = fy - screen_cy;
                let dist = (dx * dx + dy * dy).sqrt();

                if dist < max_radius && dist > 5.0 {
                    let base_angle = dy.atan2(dx);
                    let angle = base_angle + angle_offset;

                    let ux = -angle.sin() * 16.0;
                    let uy =  angle.cos() * 16.0;

                    draw_line(fx, fy, fx + ux, fy + uy, 1.5, YELLOW);
                } else {
                    draw_circle(fx, fy, 1.0, GRAY);
                }
            }
        }

        angle_offset += 0.03;
        if angle_offset > 2.0 * std::f32::consts::PI {
            angle_offset -= 2.0 * std::f32::consts::PI;
        }

        next_frame().await;
    }
}
