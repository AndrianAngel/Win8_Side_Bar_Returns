#NoTrayIcon
;#AutoIt3Wrapper_UseX64=y

#include <GUIConstants.au3>
#include <WindowsConstants.au3>
#include <TrayConstants.au3>
#include <Date.au3>
#include <Misc.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>

Opt("MustDeclareVars", True)
Opt("GUICloseOnESC", False)
Opt("TrayMenuMode", 1)
Opt("TrayAutoPause", 0)
Opt("MouseCoordMode", 2)
Opt("GUICoordMode", 1)

; ── Global variables ────────────────────────────────────────────────────────
Global $hGUI, $hDateTimeGUI
Global $iBarWidth     = 220
Global $iButtonHeight = 60
Global $iBarVisible   = False
Global $iStartY       = 0
Global $sEverythingPath = ""
Global $bBoldDateTime   = False
Global $bBoldLabels     = False
; Modifier key: 0=Alt, 1=Ctrl, 2=Shift, 3=None
Global $iModifierKey    = 0
; Hotkey string for toggle (e.g. "^b")
Global $sToggleHotkey   = "^b"

; Store control IDs - each item has [icon, label, hitarea]
Global $aMenuItems[12][3]
Global $aMenuItemNames[12] = [ _
    "Settings",      _
    "Control Panel", _
    "Uninstall Apps",          _
    "Default Apps",  _
    "WinVer",        _
    "All Apps",      _ 
    "Everything",    _
    "CMD",           _
    "Display",       _
    "Device Manager",    _
    "Calculator",    _
    "Task Manager"       _
]

; DateTime label IDs
Global $idTimeLabel, $idDateLabel, $idDayLabel

; ── Tray menu ────────────────────────────────────────────────────────────────
Local $idTrayToggle   = TrayCreateItem("Toggle Bar")
Local $idTraySettings = TrayCreateItem("Settings")
TrayCreateItem("")
Local $idTrayExit = TrayCreateItem("Exit")
TraySetState($TRAY_ICONSTATE_SHOW)

LoadSettings()
TraySetToolTip("Windows 8.1 Launch Bar")

CreateMainGUI()
CreateDateTimeGUI()

RegisterHotkeys()

; ── Main loop ────────────────────────────────────────────────────────────────
While True
    ; ── Tray messages ────────────────────────────────────────────────────────
    Switch TrayGetMsg()
        Case $idTrayToggle
            ToggleBar()
        Case $idTraySettings
            ShowSettings()
        Case $idTrayExit
            ExitLoop
    EndSwitch

    ; ── GUI messages ─────────────────────────────────────────────────────────
    Local $iMsg = GUIGetMsg()
    
    ; Check for clicks on menu items (icon, label, or hitarea)
    For $i = 0 To 11
        If $iMsg = $aMenuItems[$i][0] Or $iMsg = $aMenuItems[$i][1] Or $iMsg = $aMenuItems[$i][2] Then
            ExecuteMenuItem($i)
            ; Wait for mouse button to be fully released before resuming hide checks
            While _IsPressed("01")
                Sleep(10)
            WEnd
            ExitLoop
        EndIf
    Next

    ; ── Auto-show on right edge hover with chosen modifier ────────────────
    If Not $iBarVisible Then
        Local $aMouse = MouseGetPos()
        If $aMouse[0] >= @DesktopWidth - 3 Then
            Switch $iModifierKey
                Case 0  ; Alt
                    If _IsPressed("12") Then ShowBar()
                Case 1  ; Ctrl
                    If _IsPressed("11") Then ShowBar()
                Case 2  ; Shift
                    If _IsPressed("10") Then ShowBar()
                Case 3  ; None — mouse alone
                    ShowBar()
            EndSwitch
        EndIf
    EndIf
	
	; ── GUI messages ─────────────────────────────────────────────────────────
    Local $iMsg = GUIGetMsg()
    Local $bItemClicked = False
    
    For $i = 0 To 11
        If $iMsg = $aMenuItems[$i][0] Or $iMsg = $aMenuItems[$i][1] Or $iMsg = $aMenuItems[$i][2] Then
            ExecuteMenuItem($i)
            $bItemClicked = True
            While _IsPressed("01")
                Sleep(10)
            WEnd
            ExitLoop
        EndIf
    Next

	; ── Hide bar if click outside the bar area ────────────────────────────────
	If $iBarVisible And _IsPressed("01") Then
		AutoItSetOption("MouseCoordMode", 1)   ; switch to screen coords
		Local $aM = MouseGetPos()
		Local $aW = WinGetPos($hGUI)
		AutoItSetOption("MouseCoordMode", 2)   ; restore relative coords

		If $aM[0] < $aW[0] Or $aM[0] > $aW[0] + $aW[2] Or _
		   $aM[1] < $aW[1] Or $aM[1] > $aW[1] + $aW[3] Then
			Sleep(80)
			AutoItSetOption("MouseCoordMode", 1)
			$aM = MouseGetPos()
			AutoItSetOption("MouseCoordMode", 2)
			If $aM[0] < $aW[0] Or $aM[0] > $aW[0] + $aW[2] Or _
			   $aM[1] < $aW[1] Or $aM[1] > $aW[1] + $aW[3] Then
				HideBar()
			EndIf
		EndIf

		While _IsPressed("01")
			Sleep(10)
		WEnd
	EndIf

    Sleep(30)
WEnd

Cleanup()

; ═══════════════════════════════════════════════════════════════════════════
;  GUI CREATION
; ═══════════════════════════════════════════════════════════════════════════
Func CreateMainGUI()
    $hGUI = GUICreate("Win8Bar", $iBarWidth, @DesktopHeight, @DesktopWidth, 0, _
                       $WS_POPUP, BitOR($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST))
    ; AMOLED black background (pure black)
    GUISetBkColor(0x000000)

    Local $iTotalH = 12 * $iButtonHeight
    $iStartY = Int((@DesktopHeight - $iTotalH) / 2)
    If $iStartY < 0 Then $iStartY = 0

    Local $iIconSize = 32
    Local $iIconX = 15
    Local $iTextX = $iIconX + $iIconSize + 15
    Local $iFontWeight = $bBoldLabels ? 700 : 400

    For $i = 0 To 11
        Local $y = $iStartY + ($i * $iButtonHeight)
        Local $itemY = $y + (($iButtonHeight - $iIconSize) / 2)

        ; ── Icon (clickable) ──────────────────────────────────────────────
        Local $sIconPath = @ScriptDir & "\icons\A" & ($i + 1) & ".ico"
        Local $idIcon
        If FileExists($sIconPath) Then
            $idIcon = GUICtrlCreateIcon($sIconPath, -1, $iIconX, $itemY, $iIconSize, $iIconSize)
        Else
            $idIcon = GUICtrlCreateIcon("shell32.dll", 3, $iIconX, $itemY, $iIconSize, $iIconSize)
        EndIf

        ; ── Text label (clickable) ────────────────────────────────────────
        Local $idLabel = GUICtrlCreateLabel($aMenuItemNames[$i], $iTextX, $itemY + 5, $iBarWidth - $iTextX - 10, 22)
        GUICtrlSetColor($idLabel, 0xFFFFFF)
        GUICtrlSetFont($idLabel, 10, $iFontWeight, 0, "Segoe UI")
        GUICtrlSetBkColor($idLabel, $GUI_BKCOLOR_TRANSPARENT)

        ; ── Invisible hit area (full row for easier clicking) ─────────────
        Local $idHit = GUICtrlCreateLabel("", 0, $y, $iBarWidth, $iButtonHeight)
        GUICtrlSetBkColor($idHit, $GUI_BKCOLOR_TRANSPARENT)
        GUICtrlSetState($idHit, $GUI_DISABLE)  ; Disable to prevent focus issues

        ; Store all control IDs
        $aMenuItems[$i][0] = $idIcon
        $aMenuItems[$i][1] = $idLabel
        $aMenuItems[$i][2] = $idHit

        ; ── Separator line (very subtle) ──────────────────────────────────
        If $i < 11 Then
            Local $idSep = GUICtrlCreateLabel("", 15, $y + $iButtonHeight - 1, $iBarWidth - 30, 1)
            GUICtrlSetBkColor($idSep, 0x222222)  ; Very dark gray, almost invisible
        EndIf
    Next

    GUISetState(@SW_HIDE, $hGUI)
EndFunc

; ───────────────────────────────────────────────────────────────────────────
Func CreateDateTimeGUI()
    $hDateTimeGUI = GUICreate("Win8BarDateTime", 380, 100, 10, @DesktopHeight - 115, _
                               $WS_POPUP, BitOR($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST))
    ; Very dark background, almost black
    GUISetBkColor(0x0A0A0A)

    Local $iFontWeight = $bBoldDateTime ? 700 : 300

    $idTimeLabel = GUICtrlCreateLabel(_GetTimeStr(), 10, 8, 185, 82)
    GUICtrlSetColor($idTimeLabel, $COLOR_WHITE)
    GUICtrlSetFont($idTimeLabel, 52, $iFontWeight, 0, "Segoe UI Light")
    GUICtrlSetBkColor($idTimeLabel, $GUI_BKCOLOR_TRANSPARENT)

    $idDayLabel = GUICtrlCreateLabel(_GetDayStr(), 200, 12, 170, 34)
    GUICtrlSetColor($idDayLabel, $COLOR_WHITE)
    GUICtrlSetFont($idDayLabel, 18, $iFontWeight, 0, "Segoe UI")
    GUICtrlSetBkColor($idDayLabel, $GUI_BKCOLOR_TRANSPARENT)

    $idDateLabel = GUICtrlCreateLabel(_GetDateStr(), 200, 52, 170, 34)
    GUICtrlSetColor($idDateLabel, $COLOR_WHITE)
    GUICtrlSetFont($idDateLabel, 18, $iFontWeight, 0, "Segoe UI")
    GUICtrlSetBkColor($idDateLabel, $GUI_BKCOLOR_TRANSPARENT)

    GUISetState(@SW_HIDE, $hDateTimeGUI)
EndFunc

Func RebuildDateTimeGUI()
    GUIDelete($hDateTimeGUI)
    CreateDateTimeGUI()
EndFunc

Func RebuildMainGUI()
    GUIDelete($hGUI)
    For $i = 0 To 11
        $aMenuItems[$i][0] = 0
        $aMenuItems[$i][1] = 0
        $aMenuItems[$i][2] = 0
    Next
    CreateMainGUI()
    If $iBarVisible Then GUISetState(@SW_SHOW, $hGUI)
EndFunc

; ═══════════════════════════════════════════════════════════════════════════
;  SHOW / HIDE / TOGGLE
; ═══════════════════════════════════════════════════════════════════════════
Func ShowBar()
    If $iBarVisible Then Return
    $iBarVisible = True

    WinMove($hGUI,         "", @DesktopWidth - $iBarWidth, 0)
    WinMove($hDateTimeGUI, "", 10, @DesktopHeight - 115)

    GUISetState(@SW_SHOW, $hGUI)
    GUISetState(@SW_SHOW, $hDateTimeGUI)
    
    ; Don't activate the bar to prevent focus stealing
    ; WinActivate($hGUI)

    UpdateDateTime()
    AdlibRegister("UpdateDateTime", 5000)
EndFunc

Func HideBar()
    If Not $iBarVisible Then Return
    $iBarVisible = False

    GUISetState(@SW_HIDE, $hGUI)
    GUISetState(@SW_HIDE, $hDateTimeGUI)

    AdlibUnRegister("UpdateDateTime")
EndFunc

Func ToggleBar()
    If $iBarVisible Then
        HideBar()
    Else
        ShowBar()
    EndIf
EndFunc

; ═══════════════════════════════════════════════════════════════════════════
;  HOTKEYS
; ═══════════════════════════════════════════════════════════════════════════
Func RegisterHotkeys()
    ; Ctrl+B opens Settings
    HotKeySet("^b", "ShowSettings")
    ; Register the toggle hotkey from settings (if different from Ctrl+B)
    If $sToggleHotkey <> "^b" Then
        HotKeySet($sToggleHotkey, "ToggleBar")
    EndIf
EndFunc

Func UnregisterHotkeys()
    HotKeySet("^b")  ; Unregister Ctrl+B
    HotKeySet($sToggleHotkey)  ; Unregister toggle hotkey
EndFunc

; ═══════════════════════════════════════════════════════════════════════════
;  DATE / TIME
; ═══════════════════════════════════════════════════════════════════════════
Func _GetTimeStr()
    Return StringFormat("%02d:%02d", @HOUR, @MIN)
EndFunc

Func _GetDateStr()
    Local $aMonths[13] = ["","January","February","March","April","May","June", _
                          "July","August","September","October","November","December"]
    Return StringFormat("%d %s", @MDAY, $aMonths[@MON])
EndFunc

Func _GetDayStr()
    Local $aDays[8] = ["","Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    Return $aDays[@WDAY]
EndFunc

Func UpdateDateTime()
    If Not $iBarVisible Then Return
    GUICtrlSetData($idTimeLabel, _GetTimeStr())
    GUICtrlSetData($idDateLabel, _GetDateStr())
    GUICtrlSetData($idDayLabel,  _GetDayStr())
EndFunc

; ═══════════════════════════════════════════════════════════════════════════
;  EXECUTE MENU ITEMS
; ═══════════════════════════════════════════════════════════════════════════
Func ExecuteMenuItem($iIndex)
    Switch $iIndex
        Case 0  ; Windows Settings
            ShellExecute("ms-settings:")
        Case 1  ; Control Panel
            ShellExecute("control.exe")
        Case 2  ; Apps & Features
            ShellExecute("ms-settings:appsfeatures")
        Case 3  ; Default Apps
            ShellExecute("ms-settings:defaultapps")
        Case 4  ; WinVer
            ShellExecute("winver.exe")
        Case 5  ; All Apps - just press the Windows key (no search)
            Send("{LWINDOWN}")
            Sleep(50)
            Send("{LWINUP}")
        Case 6  ; Everything
            If FileExists($sEverythingPath) Then
                ShellExecute($sEverythingPath)
            Else
                MsgBox(48, "Error", "Everything.exe not found! Configure path in Settings.", 0, $hGUI)
            EndIf
        Case 7  ; CMD — hold Shift for admin
            If _IsPressed("10") Then
                ShellExecute("cmd.exe", "", "", "runas")
            Else
                ShellExecute("cmd.exe")
            EndIf
        Case 8  ; Display Settings
            ShellExecute("ms-settings:display")
        Case 9  ; Device Manager
            ShellExecute("devmgmt.msc")
        Case 10 ; Calculator
            ShellExecute("calc.exe")
        Case 11 ; Task Manager
            ShellExecute("taskmgr.exe")
    EndSwitch
EndFunc

; ═══════════════════════════════════════════════════════════════════════════
;  SETTINGS DIALOG  — White theme, black text with working dropdown
; ═══════════════════════════════════════════════════════════════════════════
Func ShowSettings()
    UnregisterHotkeys()

    Local $hSG = GUICreate("Settings", 440, 310, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU))
    GUISetBkColor(0xFFFFFF, $hSG)   ; white background

    Local $iLblClr  = 0x111111      ; near-black text
    Local $iInputBg = 0xF0F0F0      ; light grey inputs

    ; ── Everything path ───────────────────────────────────────────────────
    Local $idLbl1 = GUICtrlCreateLabel("Everything.exe Path:", 20, 18, 200, 20)
    GUICtrlSetColor($idLbl1, $iLblClr)
    GUICtrlSetBkColor($idLbl1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idInput = GUICtrlCreateInput($sEverythingPath, 20, 42, 310, 24)
    GUICtrlSetColor($idInput, 0x111111)
    GUICtrlSetBkColor($idInput, $iInputBg)

    Local $idBrowse = GUICtrlCreateButton("Browse...", 340, 40, 80, 28)

    ; ── Bold checkboxes ───────────────────────────────────────────────────
    Local $idBoldLabels = GUICtrlCreateCheckbox("Bold main menu labels", 20, 85, 220, 22)
    GUICtrlSetColor($idBoldLabels, $iLblClr)
    GUICtrlSetBkColor($idBoldLabels, 0xFFFFFF)
    If $bBoldLabels Then GUICtrlSetState($idBoldLabels, $GUI_CHECKED)

    Local $idBoldDateTime = GUICtrlCreateCheckbox("Bold date && time font", 20, 113, 220, 22)
    GUICtrlSetColor($idBoldDateTime, $iLblClr)
    GUICtrlSetBkColor($idBoldDateTime, 0xFFFFFF)
    If $bBoldDateTime Then GUICtrlSetState($idBoldDateTime, $GUI_CHECKED)

    ; ── Toggle hotkey field ───────────────────────────────────────────────
    Local $idLbl2 = GUICtrlCreateLabel("Toggle bar hotkey (Ctrl+B is now Settings):", 20, 148, 300, 20)
    GUICtrlSetColor($idLbl2, $iLblClr)
    GUICtrlSetBkColor($idLbl2, $GUI_BKCOLOR_TRANSPARENT)

    Local $idHKInput = GUICtrlCreateInput($sToggleHotkey, 325, 145, 70, 24)
    GUICtrlSetColor($idHKInput, 0x111111)
    GUICtrlSetBkColor($idHKInput, $iInputBg)

    Local $idHKHint = GUICtrlCreateLabel("^ = Ctrl   ! = Alt   + = Shift    (Bar: mouse to right edge)", 20, 171, 360, 16)
    GUICtrlSetColor($idHKHint, 0x666666)
    GUICtrlSetBkColor($idHKHint, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetFont($idHKHint, 8, 400, 0, "Segoe UI")

    ; ── Modifier key dropdown ─────────────────────────────────────────────
    Local $idLbl3 = GUICtrlCreateLabel("Open bar when mouse hits right edge + hold:", 20, 198, 300, 20)
    GUICtrlSetColor($idLbl3, $iLblClr)
    GUICtrlSetBkColor($idLbl3, $GUI_BKCOLOR_TRANSPARENT)

    ; FIXED: Create combo box with proper data and default selection
    Local $idModCombo = GUICtrlCreateCombo("", 325, 195, 110, 120, $CBS_DROPDOWNLIST)
    Local $sModItems = "Left Alt|Left Ctrl|Left Shift|Nothing (mouse only)"
    GUICtrlSetData($idModCombo, $sModItems)
    
    ; Set the correct default based on current setting
    Switch $iModifierKey
        Case 0
            GUICtrlSetData($idModCombo, "Left Alt")
        Case 1
            GUICtrlSetData($idModCombo, "Left Ctrl")
        Case 2
            GUICtrlSetData($idModCombo, "Left Shift")
        Case 3
            GUICtrlSetData($idModCombo, "Nothing (mouse only)")
    EndSwitch

    ; ── Save / Cancel ─────────────────────────────────────────────────────
    Local $idSave   = GUICtrlCreateButton("Save",   140, 260, 80, 32)
    GUICtrlSetColor($idSave, 0xFFFFFF)
    GUICtrlSetBkColor($idSave, 0x0078D7)   ; Windows blue

    Local $idCancel = GUICtrlCreateButton("Cancel", 235, 260, 80, 32)

    GUISetState(@SW_SHOW, $hSG)

    Local $bRebuildDT   = False
    Local $bRebuildMain = False

    While True
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $idCancel
                ExitLoop

            Case $idBrowse
                Local $sFile = FileOpenDialog("Select Everything.exe", @ProgramFilesDir, "Executable (*.exe)", 1, "Everything.exe")
                If Not @error Then GUICtrlSetData($idInput, $sFile)

            Case $idSave
                $sEverythingPath = GUICtrlRead($idInput)

                Local $bNewBoldLabels = (GUICtrlRead($idBoldLabels) = $GUI_CHECKED)
                If $bNewBoldLabels <> $bBoldLabels Then
                    $bBoldLabels = $bNewBoldLabels
                    $bRebuildMain = True
                EndIf

                Local $bNewBoldDateTime = (GUICtrlRead($idBoldDateTime) = $GUI_CHECKED)
                If $bNewBoldDateTime <> $bBoldDateTime Then
                    $bBoldDateTime = $bNewBoldDateTime
                    $bRebuildDT = True
                EndIf

                Local $sNewHK = StringStripWS(GUICtrlRead($idHKInput), 3)
                If $sNewHK = "" Then $sNewHK = "^b"
                $sToggleHotkey = $sNewHK

                ; Get selected modifier
                Local $sModSel = GUICtrlRead($idModCombo)
                Switch $sModSel
                    Case "Left Alt"
                        $iModifierKey = 0
                    Case "Left Ctrl"
                        $iModifierKey = 1
                    Case "Left Shift"
                        $iModifierKey = 2
                    Case "Nothing (mouse only)"
                        $iModifierKey = 3
                EndSwitch

                SaveSettings()
                ExitLoop
        EndSwitch
    WEnd

    GUIDelete($hSG)

    If $bRebuildMain Then RebuildMainGUI()
    If $bRebuildDT   Then RebuildDateTimeGUI()

    RegisterHotkeys()
EndFunc

; ═══════════════════════════════════════════════════════════════════════════
;  INI SAVE / LOAD
; ═══════════════════════════════════════════════════════════════════════════
Func SaveSettings()
    Local $sIni = @ScriptDir & "\launchbar.ini"
    IniWrite($sIni, "Settings", "EverythingPath", $sEverythingPath)
    IniWrite($sIni, "Settings", "BoldLabels",     $bBoldLabels)
    IniWrite($sIni, "Settings", "BoldDateTime",   $bBoldDateTime)
    IniWrite($sIni, "Settings", "ToggleHotkey",   $sToggleHotkey)
    IniWrite($sIni, "Settings", "ModifierKey",    $iModifierKey)
EndFunc

Func LoadSettings()
    Local $sIni = @ScriptDir & "\launchbar.ini"
    $sEverythingPath = IniRead($sIni, "Settings", "EverythingPath", "")
    $bBoldLabels     = (IniRead($sIni, "Settings", "BoldLabels",    "False") = "True")
    $bBoldDateTime   = (IniRead($sIni, "Settings", "BoldDateTime",  "False") = "True")
    $sToggleHotkey   = IniRead($sIni, "Settings", "ToggleHotkey",   "^b")
    $iModifierKey    = Int(IniRead($sIni, "Settings", "ModifierKey", "0"))
EndFunc

Func Cleanup()
    GUIDelete($hGUI)
    GUIDelete($hDateTimeGUI)
EndFunc