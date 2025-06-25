package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import ui "vendor:microui"
import sdl "vendor:sdl3"
import "vendor:sdl3/image"
import "vendor:sdl3/ttf"


window: ^sdl.Window = nil
renderer: ^sdl.Renderer = nil
text_engine: ^ttf.TextEngine
ui_ctx: ui.Context
quit: bool
window_size := [2]i32{800, 400}
font_icons: ^ttf.Font


main :: proc() {
	for !quit {
		handle_input()
		draw_widgets()
		execute_commmands()
	}
}

@(init)
init :: proc() {
	start := time.now()

	assert(sdl.Init({.VIDEO}))

	assert(
		sdl.CreateWindowAndRenderer(
			"test",
			window_size.x,
			window_size.y,
			sdl.WindowFlags{.HIGH_PIXEL_DENSITY, .RESIZABLE, .VULKAN},
			&window,
			&renderer,
		),
	)
	sdl.SetRenderVSync(renderer, 1)
	sdl.SetRenderDrawBlendMode(renderer, sdl.BLENDMODE_BLEND)

	assert(sdl.AddEventWatch(proc "c" (userdata: rawptr, event: ^sdl.Event) -> bool {
				if event.type == .WINDOW_PIXEL_SIZE_CHANGED {
					sdl.GetWindowSize(window, &window_size.x, &window_size.y)

					context = runtime.default_context()
					draw_widgets()
					execute_commmands()
				}
				return true
			}, nil))

	assert(sdl.StartTextInput(window))

	assert(ttf.Init())

	font_inter := ttf.OpenFont("Inter-VariableFont_opsz,wght.ttf", 20)
	font_iosevka := ttf.OpenFont("Iosevka-Regular.ttf", 20)
	font_victor_mono := ttf.OpenFont("VictorMono-Regular.ttf", 20)
	font_icons = ttf.OpenFont("icons.ttf", 20)
	assert(font_inter != nil)
	assert(font_iosevka != nil)
	assert(font_victor_mono != nil)
	assert(font_icons != nil)

	text_engine = ttf.CreateRendererTextEngine(renderer)

	ui.init(&ui_ctx, set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) {
			cstr := strings.clone_to_cstring(text, context.temp_allocator)
			sdl.SetClipboardText(cstr)
			ok = true
			return
		}, get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) {
			text = string(transmute(cstring)sdl.GetClipboardText())
			ok = true
			return
		})
	ui_ctx.draw_frame = proc(ctx: ^ui.Context, rect: ui.Rect, colorid: ui.Color_Type) {
		ui.draw_rect(ctx, rect, ctx.style.colors[colorid])
		if colorid == .SCROLL_BASE || colorid == .SCROLL_THUMB || colorid == .TITLE_BG {
			return
		}
		if ctx.style.colors[.BORDER].a != 0 {
			rect := ui.expand_rect(rect, 1)
			color := ctx.style.colors[.BORDER]
			border_thickness :: 2
			ui.draw_rect(
				ctx,
				ui.Rect {
					rect.x + border_thickness,
					rect.y,
					rect.w - border_thickness * 2,
					border_thickness,
				},
				color,
			)
			ui.draw_rect(
				ctx,
				ui.Rect {
					rect.x + border_thickness,
					rect.y + rect.h - border_thickness,
					rect.w - border_thickness * 2,
					border_thickness,
				},
				color,
			)
			ui.draw_rect(ctx, ui.Rect{rect.x, rect.y, border_thickness, rect.h}, color)
			ui.draw_rect(
				ctx,
				ui.Rect{rect.x + rect.w - border_thickness, rect.y, border_thickness, rect.h},
				color,
			)
		}
	}
	ui_ctx.style.colors[.TEXT] = {255, 255, 255, 255}
	ui_ctx.style.colors[.SELECTION_BG] = {0, 255, 0, 127}
	ui_ctx.style.colors[.BORDER] = {68, 70, 71, 255}
	ui_ctx.style.colors[.WINDOW_BG] = {31, 31, 31, 255}
	ui_ctx.style.colors[.PANEL_BG] = {42, 42, 42, 255}
	ui_ctx.style.colors[.BUTTON] = {24, 24, 24, 255}
	ui_ctx.style.colors[.BUTTON_HOVER] = {68, 70, 71, 255}
	ui_ctx.style.colors[.BUTTON_FOCUS] = {49, 49, 49, 255}
	ui_ctx.style.colors[.BASE] = {31, 31, 31, 255}
	ui_ctx.style.colors[.BASE_HOVER] = {42, 42, 42, 255}
	ui_ctx.style.colors[.BASE_FOCUS] = {49, 49, 49, 255}
	ui_ctx.style.colors[.SCROLL_BASE] = {43, 43, 43, 127}
	ui_ctx.style.colors[.SCROLL_THUMB] = {255, 255, 255, 76}
	set_font(font_victor_mono)
	ui_ctx.text_width = proc(font: ui.Font, str: string) -> (w: i32) {
		if len(str) == 0 do return 0
		assert(
			ttf.GetStringSize(
				transmute(^ttf.Font)font,
				strings.unsafe_string_to_cstring(str),
				len(str),
				&w,
				nil,
			),
		)
		return
	}
	ui_ctx.text_height = proc(font: ui.Font) -> i32 {
		// GetFontHeight :: proc(font: ^Font) -> c.int ---
		//                       ^ Apply this patch
		return ttf.GetFontHeight(transmute(^ttf.Font)font)
	}

	fmt.println("init", time.since(start))
}

handle_input :: proc() {
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			{
				sdl.Quit()
				quit = true
			}

		case .MOUSE_MOTION:
			{
				ui.input_mouse_move(&ui_ctx, i32(event.motion.x), i32(event.motion.y))
			}

		case .MOUSE_WHEEL:
			{
				ui.input_scroll(&ui_ctx, 0, i32(event.wheel.y * -30))
			}

		case .TEXT_INPUT:
			{
				ui.input_text(&ui_ctx, string(event.text.text))
			}

		case .MOUSE_BUTTON_DOWN:
			{
				ui.input_mouse_down(
					&ui_ctx,
					i32(event.button.x),
					i32(event.button.y),
					cast(ui.Mouse)(event.button.button - 1),
				)
			}

		case .MOUSE_BUTTON_UP:
			{
				ui.input_mouse_up(
					&ui_ctx,
					i32(event.button.x),
					i32(event.button.y),
					cast(ui.Mouse)(event.button.button - 1),
				)
			}

		case .KEY_DOWN:
			fallthrough
		case .KEY_UP:
			{
				@(static) sdl_scancode_to_microui_key := #partial #sparse[sdl.Scancode]ui.Key {
					sdl.Scancode.LSHIFT    = ui.Key.SHIFT,
					sdl.Scancode.LCTRL     = ui.Key.CTRL,
					sdl.Scancode.LALT      = ui.Key.ALT,
					sdl.Scancode.BACKSPACE = ui.Key.BACKSPACE,
					sdl.Scancode.DELETE    = ui.Key.DELETE,
					sdl.Scancode.RETURN    = ui.Key.RETURN,
					sdl.Scancode.LEFT      = ui.Key.LEFT,
					sdl.Scancode.RIGHT     = ui.Key.RIGHT,
					sdl.Scancode.HOME      = ui.Key.HOME,
					sdl.Scancode.END       = ui.Key.END,
					sdl.Scancode.A         = ui.Key.A,
					sdl.Scancode.X         = ui.Key.X,
					sdl.Scancode.C         = ui.Key.C,
					sdl.Scancode.V         = ui.Key.V,
				}

				scancode := event.key.scancode
				key := sdl_scancode_to_microui_key[scancode]

				key_is_none_of_the_choices := key == .SHIFT && scancode != .LSHIFT
				if key_is_none_of_the_choices do break

				if event.type == .KEY_DOWN do ui.input_key_down(&ui_ctx, key)
				else do ui.input_key_up(&ui_ctx, key)
			}
		}
	}
}

draw_widgets :: proc() {
	ui.begin(&ui_ctx)

	sdl.SetRenderDrawColor(
		renderer,
		ui_ctx.style.colors[.WINDOW_BG].r,
		ui_ctx.style.colors[.WINDOW_BG].g,
		ui_ctx.style.colors[.WINDOW_BG].b,
		ui_ctx.style.colors[.WINDOW_BG].a,
	)
	sdl.RenderClear(renderer)

	window_title :: "test"
	ctn := ui.get_container(&ui_ctx, window_title)
	ctn.rect.w = window_size.x
	ctn.rect.h = window_size.y
	ctn.body.w = window_size.x
	ctn.body.h = window_size.y
	ui.begin_window(&ui_ctx, window_title, {}, ui.Options{.NO_FRAME, .NO_TITLE, .NO_RESIZE})

	when false {
		loop_len :: 5
	} else {
		loop_len :: 1
	}
	for i in 0 ..< loop_len {
		ui.layout_row(&ui_ctx, {400, -1})

		ui.label(&ui_ctx, fmt.tprint("label", i))
		if .SUBMIT in ui.button(&ui_ctx, fmt.tprint("button", i), .NONE) {
			fmt.println("test", i)
		}

		ui.label(&ui_ctx, fmt.tprint("label", i))
		if .SUBMIT in ui.button(&ui_ctx, "", cast(ui.Icon)(i % (len(ui.Icon) - 1) + 1)) {
			fmt.println("test", i, 2)
		}

		@(static) checkbox_value: [loop_len]bool
		ui.checkbox(&ui_ctx, fmt.tprint("checkbox", i), &checkbox_value[i])
		@(static) buf := [loop_len][4096]u8{}
		@(static) text_len: [loop_len]int
		ui.textbox(&ui_ctx, buf[i][:], &text_len[i])

		@(static) value: [loop_len]ui.Real
		ui.slider(&ui_ctx, &value[i], 0, 100, 1.25)
		rect := ui.layout_next(&ui_ctx)
		text := "draw text => test ___ --- ?! ? !^"
		font := ui_ctx.style.font
		ui.draw_rect(
			&ui_ctx,
			{rect.x, rect.y, ui_ctx.text_width(font, text), ui_ctx.text_height(font)},
			{0, 255, 0, 255},
		)
		ui.draw_text(&ui_ctx, font, text, {rect.x, rect.y}, {255, 0, 0, 255})

		rect = ui.layout_next(&ui_ctx)
		text = "\ue801"
		font = transmute(ui.Font)font_icons
		ui.draw_rect(
			&ui_ctx,
			{rect.x, rect.y, ui_ctx.text_width(font, text), ui_ctx.text_height(font)},
			{0, 0, 255, 255},
		)
		ui.draw_text(&ui_ctx, font, text, {rect.x, rect.y}, {255, 0, 0, 255})
		if .ACTIVE in ui.header(&ui_ctx, fmt.tprint("header", i)) {
			ui.label(&ui_ctx, fmt.tprint("label", i))
		}
	}

	ui.end_window(&ui_ctx)

	ui.end(&ui_ctx)
}

execute_commmands :: proc() {
	cmd: ^ui.Command = nil
	for ui.next_command(&ui_ctx, &cmd) {
		switch cmd in cmd.variant {
		case ^ui.Command_Jump:
			{
			}

		case ^ui.Command_Clip:
			{
				sdl.SetRenderClipRect(
					renderer,
					nil if cmd.rect == ui.unclipped_rect else &sdl.Rect{x = cmd.rect.x, y = cmd.rect.y, w = cmd.rect.w, h = cmd.rect.h},
				)
			}

		case ^ui.Command_Rect:
			{
				sdl.SetRenderDrawColor(
					renderer,
					cmd.color.r,
					cmd.color.g,
					cmd.color.b,
					cmd.color.a,
				)
				sdl.RenderFillRect(
					renderer,
					&sdl.FRect {
						x = f32(cmd.rect.x),
						y = f32(cmd.rect.y),
						w = f32(cmd.rect.w),
						h = f32(cmd.rect.h),
					},
				)
			}

		case ^ui.Command_Text:
			{
				if len(cmd.str) <= 0 do break
				text_obj := ttf.CreateText(
					text_engine,
					transmute(^ttf.Font)cmd.font,
					strings.unsafe_string_to_cstring(cmd.str),
					len(cmd.str),
				)
				defer ttf.DestroyText(text_obj)
				assert(
					ttf.SetTextColor(text_obj, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a),
				)
				assert(ttf.DrawRendererText(text_obj, f32(cmd.pos.x), f32(cmd.pos.y)))
			}

		case ^ui.Command_Icon:
			{
				icons_base :: 0xe800
				if cmd.id == .NONE do break
				str := fmt.tprint(icons_base + cast(rune)cmd.id)
				text_obj := ttf.CreateText(
					text_engine,
					font_icons,
					strings.unsafe_string_to_cstring(str),
					len(str),
				)
				defer ttf.DestroyText(text_obj)
				assert(
					ttf.SetTextColor(text_obj, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a),
				)
				w, h: i32 = ---, ---
				assert(
					ttf.GetStringSize(
						font_icons,
						strings.unsafe_string_to_cstring(str),
						len(str),
						&w,
						&h,
					),
				)
				assert(
					ttf.DrawRendererText(
						text_obj,
						f32(cmd.rect.x + (cmd.rect.w - w) / 2),
						f32(cmd.rect.y + (cmd.rect.h - h) / 2),
					),
				)

				when false {
					sdl.SetRenderDrawColor(renderer, 0, 255, 0, 127)
					r: sdl.FRect = {
						f32(cmd.rect.x),
						f32(cmd.rect.y),
						f32(cmd.rect.w),
						f32(cmd.rect.h),
					}
					sdl.RenderFillRect(renderer, &r)
					sdl.SetRenderDrawColor(renderer, 255, 0, 0, 127)
					r.w = f32(w)
					r.h = f32(h)
					sdl.RenderFillRect(renderer, &r)
				}
			}
		}
	}

	sdl.RenderPresent(renderer)
}

set_font :: proc(font: ^ttf.Font) {
	ui_ctx.style.font = transmute(ui.Font)font
	font_size := ttf.GetFontSize(font)
	ui_ctx.style.padding = i32(font_size * 0.47)
	ui_ctx.style.thumb_size = i32(font_size * 0.44)
	ui_ctx.style.spacing = i32(font_size * 0.33)
	ui_ctx.style.scrollbar_size = i32(font_size * 0.65)
	ui_ctx.style.size.x = i32(math.ceil(font_size * 2.26))
	ui_ctx.style.size.y = i32(math.ceil(font_size * 0.55))
	//                                              ^ We balance sizes with those ratios.
	//                                                I found them by:
	//                                                 1. Search a font size that looks fine;
	//                                                 2. Divide default size's x by font size's x, same with y;
	//                                                 And more or less it will hopefully be good to go.
}
