/*
    Created on : 18-Jan-2022 04:30 PM
    Author : kcvinu
*/

package winforms
import "core:runtime"

WcCalenderClassW : wstring = to_wstring("SysMonthCal32")

Calendar :: struct
{
    using control : Control,
    value : DateTime,
    viewMode : ViewMode,
    oldView : ViewMode,
    showWeekNum : b64,
    noTodayCircle : b64,
    noToday : b64,
    noTrailingDates : b64,
    shortDayNames : b64,
    // Events
    onValueChanged,
    onViewChanged,
    onSelectionChanged : EventHandler,
}

// Enum for setting Calendar's view mode.
// Posible values : month, year, decade, centuary
ViewMode :: enum {Month, Year, Decade, Centuary}

@private calendar_ctor :: proc(p : ^Form, x, y : int) -> ^Calendar
{
    if !isDtpClassInit { // Then we need to initialize the date class control.
        isDtpClassInit = true
        app.iccx.dwIcc = ICC_DATE_CLASSES
        InitCommonControlsEx(&app.iccx)
    }
    this := new(Calendar)
    this.parent = p
    this.font = p.font
    this.kind = .Calendar
    this.width = 0
    this.height = 0
    this.xpos = x
    this.ypos = y
    this._style = WS_CHILD | WS_VISIBLE //| MCS_DAYSTATE
    this._clsName = WcCalenderClassW
    this._fp_beforeCreation = cast(CreateDelegate) cal_before_creation
	this._fp_afterCreation = cast(CreateDelegate) cal_after_creation
    append(&p._controls, this)
    return this
}

// Create a new Calendar control.
new_calendar :: proc{new_cal1, new_cal2}

@private new_cal1 :: proc(parent : ^Form, x, y : int, autoc: b8 = false) -> ^Calendar
{
    c := calendar_ctor(parent, x, y)
    if autoc do create_control(c)
    return c
}

@private new_cal2 :: proc(parent : ^Form, autoc: b8 = false) -> ^Calendar
{
    c := calendar_ctor(parent, 10, 10)
    if autoc do create_control(c)
    return c
}

// Api constants.
    MCM_FIRST :: 0x1000
    MCM_GETMINREQRECT :: (MCM_FIRST + 9)
    MCM_SETCOLOR :: (MCM_FIRST + 10)
    MCM_GETCALENDARGRIDINFO :: (MCM_FIRST + 24)

    MCN_FIRST :: 4294966550
    MCN_GETDAYSTATE :: (MCN_FIRST + 3)
    MCN_SELCHANGE :: (MCN_FIRST - 3)
    MCN_SELECT :: MCN_FIRST
    MCN_VIEWCHANGE :: (MCN_FIRST-4)

    MCMV_MONTH :: 0
    MCMV_YEAR :: 1
    MCMV_DECADE :: 2
    MCMV_CENTURY :: 3
    MCMV_MAX :: MCMV_CENTURY

    MCGIP_CALENDARBODY :: 6
    MCGIP_CALENDAR :: 4
    MCGIF_RECT :: 0x2

    //NM_RELEASEDCAPTURE :: 4294967280

// End of API constants.

// Api Types
    NMSELCHANGE :: struct
    {
        nmhdr : NMHDR,
        stSelStart,
        stSelEnd : SYSTEMTIME,
    }

    NMVIEWCHANGE :: struct
    {
        nmhdr : NMHDR,
        dwOldView : DWORD,
        dwNewView : DWORD,
    }

    MCGRIDINFO :: struct
    {
        cbSize : UINT,
        dwPart : DWORD,
        dwFlags : DWORD,
        iCalendar : i32,
        iRow : i32,
        iCol : i32,
        bSelecte : bool,
        stStart : SYSTEMTIME,
        stEnd : SYSTEMTIME,
        rc : RECT,
        pszName : wstring,
        cchNam : size_t,
    }

    NMMOUSE :: struct
    {
        nmhdr : NMHDR,
        dwItemSpec : DWORD_PTR,
        dwItemData : DWORD_PTR,
        pt : POINT,
        dwHitInfo : LPARAM,

    }

// End of API Types

@private set_cal_style :: proc(c : ^Calendar)
{
    if c.showWeekNum do c._style |= MCS_WEEKNUMBERS
    if c.noTodayCircle do c._style |= MCS_NOTODAYCIRCLE
    if c.noToday do c._style |= MCS_NOTODAY
    if c.noTrailingDates do c._style |= MCS_NOTRAILINGDATES
    if c.shortDayNames do c._style |= MCS_SHORTDAYSOFWEEK
}

@private cal_before_creation :: proc(c : ^Calendar)
{
    set_cal_style(c)
}

@private cal_after_creation :: proc(cal : ^Calendar)
{
    set_subclass(cal, cal_wnd_proc)
    rc : RECT
    SendMessage(cal.handle, MCM_GETMINREQRECT, 0, convert_to(LPARAM, &rc))
    SetWindowPos(cal.handle, nil, i32(cal.xpos), i32(cal.ypos), rc.right, rc.bottom, SWP_NOZORDER)
}

@private calendar_property_setter :: proc(this: ^Calendar, prop: CalendarProps, value: $T)
{
	#partial switch prop {
		case .Value:
            when T == DateTime {
                this.value = value
                if this._isCreated {
                    st := datetime_to_systime(this.value)
                    SendMessage(this.handle, MCM_SETCURSEL, 0, &st)
                }
            }
		case .View_Mode:
            when T == ViewMode {
                this.viewMode = value
                if this._isCreated do SendMessage(this.handle, MCM_SETCURRENTVIEW, 0, i32(this.viewMode))
            }

		// case .Old_View: break
		// case .Show_Week_Num: control_enable(this, bool(value))
		// case .No_Today_Circle: control_set_size(this, this.width, int(value))
		// case .No_Today: control_set_text(this, tostring(value))
		// case .No_Trailing_Dates: control_visibile(this, bool(value))
		// case .Short_Day_Names: control_set_size(this, int(value), this.height)
	}
}


@private cal_finalize :: proc(cal: ^Calendar, scid: UINT_PTR)
{
    RemoveWindowSubclass(cal.handle, cal_wnd_proc, scid)
    free(cal)
}

@private cal_wnd_proc :: proc "std" (hw : HWND, msg : u32, wp : WPARAM, lp : LPARAM,
                                            sc_id : UINT_PTR, ref_data : DWORD_PTR) -> LRESULT
{
    // context = runtime.default_context()
    context = global_context
    cal := control_cast(Calendar, ref_data)
   //display_msg(msg)
    switch msg {

        case WM_PAINT :
            if cal.paint != nil {
                ps : PAINTSTRUCT
                hdc := BeginPaint(hw, &ps)
                pea := new_paint_event_args(&ps)
                cal.paint(cal, &pea)
                EndPaint(hw, &ps)
                return 0
            }

        case WM_CONTEXTMENU:
		    if cal.contextMenu != nil do contextmenu_show(cal.contextMenu, lp)

        case CM_NOTIFY :
            nm := direct_cast(lp, ^NMHDR)
            //print("nm.code - ", nm.code)
            switch nm.code {
                case MCN_SELECT:
                    nms := direct_cast(lp, ^NMSELCHANGE)
                    cal.value = systime_to_datetime(nms.stSelStart)
                    if cal.onValueChanged != nil {
                        ea := new_event_args()
                        cal.onValueChanged(cal, &ea)
                    }

                case MCN_SELCHANGE :
                    nms := direct_cast(lp, ^NMSELCHANGE)
                    cal.value = systime_to_datetime(nms.stSelStart)
                    if cal.onSelectionChanged != nil {
                        ea := new_event_args()
                        cal.onSelectionChanged(cal, &ea)
                    }

                case MCN_VIEWCHANGE:
                    nmv := direct_cast(lp, ^NMVIEWCHANGE)
                    cal.viewMode = ViewMode(nmv.dwNewView)
                    cal.oldView = ViewMode(nmv.dwOldView)
                    if cal.onViewChanged != nil {
                        ea := new_event_args()
                        cal.onViewChanged(cal, &ea)
                    }
            }

         case WM_MOUSEHWHEEL:
            if cal.onMouseScroll != nil {
                mea := new_mouse_event_args(msg, wp, lp)
                cal.onMouseScroll(cal, &mea)
            }

        case WM_MOUSEMOVE : // Mouse Enter & Mouse Move is happening here.
            if cal._isMouseEntered {
                if cal.onMouseMove != nil {
                    mea := new_mouse_event_args(msg, wp, lp)
                    cal.onMouseMove(cal, &mea)
                }
            } else {
                cal._isMouseEntered = true
                if cal.onMouseEnter != nil  {
                    ea := new_event_args()
                    cal.onMouseEnter(cal, &ea)
                }
            }

        case WM_MOUSELEAVE :
            cal._isMouseEntered = false
            if cal.onMouseLeave != nil {
                ea := new_event_args()
                cal.onMouseLeave(cal, &ea)
            }


            case WM_LBUTTONDOWN:
            cal._mDownHappened = true
            if cal.onMouseDown != nil {
                mea := new_mouse_event_args(msg, wp, lp)
                cal.onMouseDown(cal, &mea)
                return 0
            }

        case WM_RBUTTONDOWN:
            cal._mRDownHappened = true
            if cal.onRightMouseDown != nil {
                mea := new_mouse_event_args(msg, wp, lp)
                cal.onRightMouseDown(cal, &mea)
            }

        case WM_LBUTTONUP :
            if cal.onMouseUp != nil {
                mea := new_mouse_event_args(msg, wp, lp)
                cal.onMouseUp(cal, &mea)
            }
            if cal._mDownHappened {
                cal._mDownHappened = false
                SendMessage(cal.handle, CM_LMOUSECLICK, 0, 0)
            }

        case CM_LMOUSECLICK :
            cal._mDownHappened = false
            if cal.onMouseClick != nil {
                ea := new_event_args()
                cal.onMouseClick(cal, &ea)
                return 0
            }

        case WM_LBUTTONDBLCLK :
            if cal.onDoubleClick != nil {
                ea := new_event_args()
                cal.onDoubleClick(cal, &ea)
                return 0
            }

        case WM_RBUTTONUP :
            if cal.onRightMouseUp != nil {
                mea := new_mouse_event_args(msg, wp, lp)
                cal.onRightMouseUp(cal, &mea)
            }
            if cal._mRDownHappened {
                cal._mRDownHappened = false
                SendMessage(cal.handle, CM_LMOUSECLICK, 0, 0)
            }

        case CM_RMOUSECLICK :
            cal._mRDownHappened = false
            if cal.onRightClick != nil {
                ea := new_event_args()
                cal.onRightClick(cal, &ea)
                return 0
            }
        case WM_DESTROY: cal_finalize(cal, sc_id)

        case :
        return DefSubclassProc(hw, msg, wp, lp)

    }
    return DefSubclassProc(hw, msg, wp, lp)
}
