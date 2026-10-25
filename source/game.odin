package game

import "core:c"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

HEIGHT :: 180
PIT_HEIGHT :: 48

Pipe :: struct {
	pos_x:      i32,
	pit_y:      i32,
	pit_height: i32,
}

Animation :: struct {
	frame_num:   int,
	frame_count: int,
	frame_time:  f32,
	timer:       f32,
}


run: bool
pipe_texture: rl.Texture
pipe_bottom_texture: rl.Texture
sky: rl.Texture
bird_texture: rl.Texture
reset_texture: rl.Texture
bird_animation: Animation

coin_sound: rl.Sound
swing_sound: rl.Sound
lost_sound: rl.Sound

pos: rl.Vector2
vel: rl.Vector2
pipes: [10]Pipe

last_passed_pipe_x: i32
score: i32
lost: bool

debug: bool = false

// Rotated rect (center, half extents, angle in degrees) vs axis-aligned rec.
check_collision_rotated_rec :: proc(
	center, half: rl.Vector2,
	angle_deg: f32,
	rec: rl.Rectangle,
) -> bool {
	rad := angle_deg * rl.DEG2RAD
	cs, sn := math.cos(rad), math.sin(rad)
	acs, asn := abs(cs), abs(sn)

	rec_half := rl.Vector2{rec.width / 2, rec.height / 2}
	d := rl.Vector2{rec.x, rec.y} + rec_half - center

	// World X / Y axes
	if abs(d.x) > rec_half.x + half.x * acs + half.y * asn do return false
	if abs(d.y) > rec_half.y + half.x * asn + half.y * acs do return false

	// Bird's rotated axes: (cs, sn) and (-sn, cs)
	if abs(d.x * cs + d.y * sn) > half.x + rec_half.x * acs + rec_half.y * asn do return false
	if abs(-d.x * sn + d.y * cs) > half.y + rec_half.x * asn + rec_half.y * acs do return false

	return true
}

init_pipes :: proc(pipes: ^[10]Pipe) {
	for &pipe, index in pipes {
		pipe = Pipe {
			pos_x      = i32((index + 1) * 100),
			pit_y      = rand.int32_range(PIT_HEIGHT / 2 + 10, HEIGHT - (PIT_HEIGHT / 2) - 10),
			pit_height = PIT_HEIGHT,
		}
	}
}

init :: proc() {
	run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib on the web")
	rl.InitAudioDevice()
	rl.SetMasterVolume(0.5)

	coin_sound = rl.LoadSound("assets/coin.mp3")
	swing_sound = rl.LoadSound("assets/swing.mp3")
	lost_sound = rl.LoadSound("assets/lost.mp3")

	pipe_texture = rl.LoadTexture("assets/pipe.png")
	pipe_bottom_texture = rl.LoadTexture("assets/pipe_bottom.png")
	sky = rl.LoadTexture("assets/night_sky.png")
	reset_texture = rl.LoadTexture("assets/reset_button.png")

	bird_animation = Animation {
		frame_count = 3,
		frame_num   = 0,
		frame_time  = 0.2,
		timer       = 0.2,
	}

	bird_texture = rl.LoadTexture("assets/bird-sheet.png")

	pos = rl.Vector2{20, 20}

	init_pipes(&pipes)
}

update :: proc() {
	if rl.IsKeyPressed(.D) {
		debug = !debug
	}
	if !lost {
		if bird_animation.frame_num < 2 {
			bird_animation.timer -= rl.GetFrameTime()
			if bird_animation.timer <= 0 {
				bird_animation.frame_num += 1
				bird_animation.timer = bird_animation.frame_time + bird_animation.timer
			}
		}

		vel.x = 57

		vel.y += 500 * rl.GetFrameTime()
		if vel.y > 400 {
			vel.y = 400
		}

		if rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT) {
			vel.y = -170
			bird_animation.frame_num = 0
			bird_animation.timer = 0.2
			rl.PlaySound(swing_sound)
		}

		pos += vel * rl.GetFrameTime()

		if pos.x - f32(last_passed_pipe_x) > 120 {
			rl.PlaySound(coin_sound)
			last_passed_pipe_x = (i32(pos.x) / 100) * 100
			score += 1

			last_pipe_x: i32 = 0
			for pipe in pipes {
				if pipe.pos_x > last_pipe_x {
					last_pipe_x = i32(pipe.pos_x)
				}
			}
			for &pipe in pipes {
				if pipe.pos_x - i32(pos.x) < -200 {
					pipe = {
						pos_x      = last_pipe_x + 100,
						pit_y      = rand.int32_range(
							PIT_HEIGHT / 2 + 10,
							HEIGHT - (PIT_HEIGHT / 2) - 10,
						),
						pit_height = PIT_HEIGHT,
					}
					break
				}
			}
		}

		// Check collisions
		bird_angle := (vel.y - 100) / 6.6
		bird_center := pos + {8, 8}
		bird_half := rl.Vector2{6, 3}
		for pipe in pipes {
			upper_pipe_rec := rl.Rectangle {
				x      = f32(pipe.pos_x),
				y      = f32(pipe.pit_y - (pipe.pit_height / 2) - pipe_texture.height),
				width  = f32(pipe_texture.width - 7),
				height = f32(pipe_texture.height),
			}
			bottom_pipe_rec := rl.Rectangle {
				x      = f32(pipe.pos_x),
				y      = f32(pipe.pit_y + (pipe.pit_height / 2)),
				width  = f32(pipe_texture.width - 7),
				height = f32(pipe_texture.height),
			}
			if check_collision_rotated_rec(bird_center, bird_half, bird_angle, upper_pipe_rec) ||
			   check_collision_rotated_rec(bird_center, bird_half, bird_angle, bottom_pipe_rec) {
				lost = true
				rl.PlaySound(lost_sound)
			}
		}

		if pos.y < 0 || pos.y > HEIGHT - 16 {
			lost = true
			rl.PlaySound(lost_sound)
		}

	}

	rl.BeginDrawing()

	rl.ClearBackground(rl.SKYBLUE)
	sky_source := rl.Rectangle{0, 0, f32(sky.width), f32(sky.height)}
	sky_dest: rl.Rectangle
	if f32(sky.width) / f32(sky.height) > f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight()) {
		sky_dest.height = f32(rl.GetScreenHeight())
		sky_dest.width = f32(sky.width) * (f32(rl.GetScreenHeight()) / f32(sky.height))
	} else {
		sky_dest.width = f32(rl.GetScreenWidth())
		sky_dest.height = f32(sky.height) * (f32(rl.GetScreenWidth()) / f32(sky.width))
	}

	rl.DrawTexturePro(sky, sky_source, sky_dest, {0, 0}, 0, rl.WHITE)

	camera := rl.Camera2D {
		target   = {pos.x, 0},
		offset   = {100, 0},
		zoom     = f32(rl.GetScreenHeight()) / HEIGHT,
		rotation = 0,
	}

	rl.BeginMode2D(camera)


	source := rl.Rectangle {
		x      = f32(bird_animation.frame_num * 16),
		y      = 0,
		width  = 16,
		height = 16,
	}

	dest := rl.Rectangle {
		x      = pos.x + 8,
		y      = pos.y + 8,
		width  = 16,
		height = 16,
	}

	angle := (vel.y - 100) / 6.6
	rl.DrawTexturePro(bird_texture, source, dest, {8, 8}, angle, rl.WHITE)
	if debug {rl.DrawRectanglePro({pos.x + 8, pos.y + 8, 12, 6}, {6, 3}, angle, {255, 0, 0, 100})}
	//rl.DrawCircleV(ellipse_dest, 16, {255, 0, 0, 100})

	for pipe in pipes {

		upper_pipe_source := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = f32(pipe_texture.width),
			height = f32(pipe_texture.height),
		}

		upper_pipe_dest := rl.Rectangle {
			x      = f32(pipe.pos_x),
			y      = f32(pipe.pit_y - (pipe.pit_height / 2) - pipe_texture.height),
			width  = f32(pipe_texture.width - 7),
			height = f32(pipe_texture.height),
		}

		rl.DrawTexturePro(pipe_texture, upper_pipe_source, upper_pipe_dest, {0, 0}, 0, rl.WHITE)

		bottom_pipe_source := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = f32(pipe_bottom_texture.width),
			height = f32(pipe_bottom_texture.height),
		}

		bottom_pipe_dest := rl.Rectangle {
			x      = f32(pipe.pos_x),
			y      = f32(pipe.pit_y + (pipe.pit_height / 2)),
			width  = f32(pipe_bottom_texture.width - 7),
			height = f32(pipe_bottom_texture.height),
		}

		rl.DrawTexturePro(
			pipe_bottom_texture,
			bottom_pipe_source,
			bottom_pipe_dest,
			{0, 0},
			0,
			rl.WHITE,
		)

	}

	rl.EndMode2D()

	if !lost {
		text := rl.TextFormat("%d", score)
		text_width := rl.MeasureText(text, 50)
		//rl.DrawText(, 0, rl.GetScreenHeight() - 20, 20, rl.GREEN)
		rl.DrawText(
			text,
			rl.GetScreenWidth() / 2 - text_width / 2,
			rl.GetScreenHeight() / 6,
			50,
			rl.ORANGE,
		)
	} else {
		text := rl.TextFormat("Score: %d", score)
		text_width := rl.MeasureText(text, 50)
		rl.DrawText(
			text,
			rl.GetScreenWidth() / 2 - text_width / 2,
			rl.GetScreenHeight() / 2 - 70,
			50,
			rl.RED,
		)

		reset_zoom := 7
		reset_dest := rl.Rectangle {
			f32(rl.GetScreenWidth()) / 2 - f32(reset_texture.width) * f32(reset_zoom) / 2,
			f32(rl.GetScreenHeight()) / 2,
			f32(reset_texture.width) * f32(reset_zoom),
			f32(reset_texture.height) * f32(reset_zoom),
		}

		rl.DrawTexturePro(
			reset_texture,
			{0, 0, f32(reset_texture.width), f32(reset_texture.height)},
			reset_dest,
			{0, 0},
			0,
			rl.WHITE,
		)
		if (rl.IsMouseButtonPressed(.LEFT) &&
			   rl.CheckCollisionPointRec(rl.GetMousePosition(), reset_dest)) ||
		   rl.IsKeyPressed(.ENTER) ||
		   rl.IsMouseButtonPressed(.RIGHT) {
			pos = 0
			vel = 0
			init_pipes(&pipes)

			last_passed_pipe_x = 0
			score = 0
			lost = false
		}
	}

	rl.EndDrawing()
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
}

shutdown :: proc() {
	rl.CloseWindow()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			run = false
		}
	}

	return run
}
