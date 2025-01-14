package winforms
import "core:fmt"
import "core:runtime"
import "core:intrinsics"
import "core:mem"
import api "core:sys/windows"

// My Own messages

	ptf :: fmt.printf
	print :: fmt.println
	MSG_FIXED_VALUE :: 9000
	CM_NOTIFY :: MSG_FIXED_VALUE + 1
	CM_CTLLCOLOR :: MSG_FIXED_VALUE + 2
	CM_LABELDRAW :: MSG_FIXED_VALUE + 3
	CM_LMOUSECLICK :: MSG_FIXED_VALUE + 4
	CM_RMOUSECLICK :: MSG_FIXED_VALUE + 5
	CM_TBTXTCHANGED :: MSG_FIXED_VALUE + 6
	CM_CBCOLOR :: MSG_FIXED_VALUE  + 7
	CM_CTLCOMMAND :: MSG_FIXED_VALUE + 8
	CM_PARENTNOTIFY :: MSG_FIXED_VALUE + 9
	CM_COMBOLBCOLOR :: MSG_FIXED_VALUE + 10
	CM_COMBOTBCOLOR :: MSG_FIXED_VALUE + 11
	CM_GBFORECOLOR :: MSG_FIXED_VALUE + 12
	CM_HSCROLL :: MSG_FIXED_VALUE + 13
	CM_VSCROLL :: MSG_FIXED_VALUE + 14
	CM_TVNODEEXPAND :: MSG_FIXED_VALUE + 15
	CM_BUDDY_RESIZE :: MSG_FIXED_VALUE + 16
	CM_MENU_ADDED :: MSG_FIXED_VALUE + 17



// My Own messages

// All controls has a default back & fore color.
def_back_clr :: 0xFFFFFF
def_fore_clr :: 0x000000



// Controls like window & button wants to paint themselve with a gradient brush.
// In that cases, we need an option for painting in two directions.
// So this enum will be used in controls which had the ebility to draw a gradient bkgnd.
GradientStyle :: enum {Top_To_Bottom, Left_To_Right,}
TextAlignment :: enum {Top_Left, Top_Center, Top_Right, Mid_Left, Center, Mid_Right, Bottom_Left, Bottom_Center, Bottom_Right}
SimpleTextAlignment :: enum {Left, Center, Right}
TicPosition :: enum {Down_Side, Up_Side, Left_Side, Right_Side, Both_Side} // For trackbar


TimeMode :: enum {Nano_Sec, Micro_Sec, Milli_Sec}

Time :: struct {_nano_sec : i64,}
SizeIncrement :: struct {width, height : int,}
Area :: struct {width, height : int,}
WordValue :: enum {Low, High}

to_str :: proc(value : any) -> string {return fmt.tprint(value)}
L :: intrinsics.constant_utf16_cstring

current_time_internal :: proc() -> Time
{
	ftime : FILETIME
	GetSysTimeAsFileTime(&ftime)
	ns := FILETIME_as_unix_nanoseconds(ftime)
	return Time{_nano_sec = ns}
}

current_filetime :: proc(tm : TimeMode) -> i64
{
	result : i64
	n := current_time_internal()
	switch tm {
		case .Nano_Sec : result = n._nano_sec
		case .Micro_Sec : result = n._nano_sec / 1000
		case .Milli_Sec : result = n._nano_sec / 1000000
	}
	return result
}

create_hbrush :: proc(clr : uint) -> HBRUSH
{
	cref := get_color_ref(clr)
	return CreateSolidBrush(cref)
}

draw_ellipse :: proc(dch : HDC, rc : RECT)
{
	Ellipse(dch, rc.left, rc.top, rc.right, rc.bottom)
}

@private get_ctrl_text_internal :: proc(hw : HWND, alloc := context.allocator) -> string
{
	tlen := GetWindowTextLength(hw)
	wsBuffer := make([]WCHAR, tlen + 1, alloc)
	// wsBuffer : wstring = &mem_chunks[0]
	defer delete(wsBuffer)
	GetWindowText(hw, &wsBuffer[0], i32(len(wsBuffer)))
	return utf16_to_utf8(wsBuffer, alloc)
}

@private calculate_ctl_size :: proc(ctl : ^Control)
{
	ss : SIZE
    SendMessage(ctl.handle, BCM_GETIDEALSIZE, 0, direct_cast( &ss, LPARAM))
    ctl.width = int(ss.width)
    ctl.height = int(ss.height)
    MoveWindow(ctl.handle, i32(ctl.xpos), i32(ctl.ypos), ss.width, ss.height, true)
}

@private in_range :: proc(value, min_val, max_val : i32) -> bool
{
	if value > min_val && value < max_val do return true
	return false
}

@private alert :: proc(txt : string)
{
	@static cntr : int = 1
	ptf("%s - [%d]\n", txt, cntr)
	cntr += 1
}

@private alert2 :: proc(txt : string, data : any)
{
	@static cntr : int = 1
	ptf("[%d] %s - %s\n", cntr, txt, fmt.tprint(data))
	cntr += 1
}

concat_number :: proc{concat_number1, concat_number2}
concat_number1 :: proc(value : string, num : int ) -> string {return fmt.tprint(args = {value, num},sep = "")}
concat_number2 :: proc(value : string, num : uint ) -> string {return fmt.tprint(args = {value, num},sep = "")}

direct_cast :: proc(value : $T, $tp : typeid) -> tp
{
	up := cast(UINT_PTR) value
	return cast(tp) up
}

convert_to :: proc($tp : typeid, value : $T) -> tp
{
	up := cast(UINT_PTR) cast(rawptr) value
	return cast(tp) up
}

to_lparam :: proc(value: $T) -> LPARAM
{
	up := cast(UINT_PTR) value
	return cast(LPARAM) up
}

to_wparam :: proc(value: $T) -> WPARAM
{
	up := cast(UINT_PTR) value
	return cast(WPARAM) up
}

to_dwptr :: proc(ctl : ^Control) -> DWORD_PTR
{
	up := cast(UINT_PTR) ctl
	return cast(DWORD_PTR) up
}

get_rect :: proc(hw : HWND) -> RECT
{
	rct : RECT
	GetClientRect(hw, &rct)
	return rct
}

get_win_rect :: proc(hw : HWND) -> RECT
{
	rc : RECT
	GetWindowRect(hw, &rc)
	return rc
}

make_dword :: proc(lo_val, hi_val, : $T) -> DWORD
{
	hv := cast(WORD) hi_val
    lv := cast(WORD) lo_val
	dw_val := DWORD(DWORD(lv) | (DWORD(hv)) << 16)
	return dw_val
}

tostring :: proc(value: $T) -> string
{
	sitem : string
    when T == string {
        sitem = item
    } else {
        sitem = fmt.tprint(value)
    }
	return sitem
}
// left = loword, right side - highword

// There a lot of time we need to convert a handle like HBrush to HGDIOBJ.
// This proc will help for it.
to_hgdi_obj :: proc(value : $T ) -> HGDIOBJ {return cast(HGDIOBJ) value}
to_lresult :: proc(value : $T) -> LRESULT
{
	up := cast(UINT_PTR) value
	return cast(LRESULT) up
}

// If we want to get the virtual key code (VK_KEY_NUMPAD1 etc) from lparam...
// in any keyboard related message, this proc helps to extract it
get_virtual_key :: proc(value : LPARAM) -> u32
{
	scan_code : u32 = u32(value >> 16 )
    return MapVirtualKey(scan_code, MAPVK_VSC_TO_VK)
}

get_x_lparam :: proc(lpm : LPARAM) -> int { return int(i16(loword_lparam(lpm)))}
get_y_lparam :: proc(lpm : LPARAM) -> int { return int(i16(hiword_lparam(lpm)))}

get_mouse_points :: proc(lpm : LPARAM) -> POINT  // Used in mouse messages
{
	pt : POINT
	pt.x = i32(loword_lparam(lpm))
	pt.y = i32(hiword_lparam(lpm))
	return pt
}

get_mouse_pos_on_msg :: proc() -> POINT
{
	result : POINT
    dw_value := GetMessagePos()
    result.x = LONG(lo_word(dw_value))
    result.y = LONG(hi_word(dw_value))
	return result
}

loword_wparam :: #force_inline proc "contextless" (x : WPARAM) -> WORD { return WORD(x & 0xffff)}
hiword_wparam :: #force_inline proc "contextless" (x : WPARAM) -> WORD { return WORD(x >> 16)}
loword_lparam :: #force_inline proc "contextless" (x : LPARAM) -> WORD { return WORD(x & 0xffff)}
hiword_lparam :: #force_inline proc "contextless" (x : LPARAM) -> WORD { return WORD(x >> 16)}

@private select_gdi_object :: proc(hd : HDC, obj : $T)
{
	gdi_obj := cast(HGDIOBJ) obj
	SelectObject(hd, gdi_obj)
}

@private delete_gdi_object :: proc(obj : $T)
{
	gdi_obj := cast(HGDIOBJ) obj
	DeleteObject(gdi_obj)
}

@private dynamic_array_search :: proc(arr : [dynamic]$T, item : T) -> (index : int, is_found : bool)
{
	for i := 0 ; i < len(arr) ; i += 1 {
		if arr[i] == item {
			index = i
			is_found = true
			break
		}
	}
	return index, is_found
}

@private static_array_search :: proc(arr : []$T, item : T) -> (index : int, is_found : bool)
{
	for i := 0 ; i < len(arr) ; i += 1 {
		if arr[i] == item {
			index = i
			is_found = true
			break
		}
	}
	return index, is_found
}

array_search :: proc{	dynamic_array_search, static_array_search,}

// This proc will return an HBRUSH to paint the window or a button in gradient colors.
@private create_gradient_brush :: proc(hdc : HDC, rct : RECT, c1, c2 : Color, t2b : bool = true) -> HBRUSH
{
	t_brush : HBRUSH
	mem_hdc : HDC = CreateCompatibleDC(hdc)
	hbmp : HBITMAP = CreateCompatibleBitmap(hdc, rct.right, rct.bottom)
	loop_end : i32 = rct.bottom if t2b else rct.right

	SelectObject(mem_hdc, HGDIOBJ(hbmp))
	i : i32
	for i = 0; i < loop_end; i += 1 {
		t_rct : RECT
		r, g, b : uint

		r = c1.red + uint((i * i32(c2.red - c1.red) / loop_end))
        g = c1.green + uint((i * i32(c2.green - c1.green) / loop_end))
        b = c1.blue + uint((i * i32(c2.blue - c1.blue) / loop_end))
		t_brush = CreateSolidBrush(get_color_ref(r, g, b))

		t_rct.left = 0 if t2b else i
		t_rct.top = i if t2b else 0
		t_rct.right = rct.right if t2b else i + 1
		t_rct.bottom = i + 1 if t2b else loop_end
		api.FillRect(mem_hdc, &t_rct, t_brush)
		DeleteObject(HGDIOBJ(t_brush))
	}
	gradient_brush : HBRUSH = CreatePatternBrush(hbmp)
	DeleteDC(mem_hdc)
	DeleteObject(HGDIOBJ(t_brush))
	DeleteObject(HGDIOBJ(hbmp))
	return gradient_brush
}


// @private
// print_rect :: proc(rc : RECT) {
// 	ptf("left : %d\n", rc.left)
// 	ptf("top : %d\n", rc.top)
// 	ptf("right : %d\n", rc.right)
// 	ptf("bottom : %d\n", rc.bottom)
// 	print("----------------------------------------------------")
// }

@private set_rect :: proc(rc : ^RECT, left, top, right, bottom: i32)
{
	rc.left = left
	rc.top = top
	rc.right = right
	rc.bottom = bottom
}

Test :: proc()
{
	dw : DWORD = 100 | 200 | 300
	ptf("dw in decimal %d\n", dw)
	ptf("dw in binary %b\n", dw)
	ptf("dw in hex %X\n", dw)
}

// Create a Control. Use this for all controls.
create_control :: proc(c : ^Control)
{
	// If it's a Combobox, it knows how to manage contril ID.
	if c.kind != ControlKind.Combo_Box {
		globalCtlID += 1
    	c.controlID = globalCtlID
	}

	c._fp_beforeCreation(c)
	width : i32 = 0
	height : i32 = 0
	if c.kind != ControlKind.Number_Picker {
		// NumberPicker needs zero width & height. It can find it's size later.
		width = i32(c.width)
		height = i32(c.height)
	}
	ctrl_txt_ptr : LPCWSTR = c.text == "" ? nil: to_wstring(c.text)

    c.handle = CreateWindowEx(  c._exStyle,
								c._clsName,
								ctrl_txt_ptr,
								c._style,
								i32(c.xpos),
								i32(c.ypos),
								width,
								height,
								c.parent.handle,
								direct_cast(c.controlID, HMENU),
								app.hInstance,
								nil )
	// ptf("Creation res %d\n", GetLastError())

    if c.handle != nil {
        c._isCreated = true
        setfont_internal(c)
		c._fp_afterCreation(c)
		// context = runtime.default_context()
    }
}

create_handle :: proc(ctl : ^Control)
{
	if ctl.kind == .Form {
		create_form(cast(^Form) ctl)
	} else {
		create_control(ctl)
	}
}

create_controls :: proc(ctls : ..^Control)
{
	for c in ctls {
		create_control(c)
	}
}

show_memory_report :: proc(track: ^mem.Tracking_Allocator)
{
    for _, v in track.allocation_map { ptf("%v leaked %v bytes\n", v.location, v.size) }
    for bf in track.bad_free_array { ptf("%v allocation %p was freed badly\n", bf.location, bf.memory) }
}
