#include "WEQ2.Settings.iss"

; Controller for a WinEQ 2022 Session (game instance)
objectdef weq2022session
{
    ; a Task Manager is used to execute our hotkeys
    variable taskmanager TaskManager=${LMAC.NewTaskManager["weq2022Session"]}

    ; the WinEQ 2 settings object
    variable weq2settings Settings

    ; the WinEQ 2 folder to use
    variable string WinEQ2Folder="C:\\Program Files (x86)\\WinEQ2"

    ; References to the current Profile and the current Preset
    variable weakref CurrentProfile
    variable weakref CurrentPreset

    ; Have we already set up the game window?
    variable bool GameWindowSetup=FALSE

    ; A copy of the Global Hotkey we're set to use. This default value gets overwritten by a valid Profile
    variable string UseGlobalHotkey="Ctrl+Alt+${JMB.Slot.ID}"

    ; The preset selected in GUI, which is not necessarily activated
    variable uint SelectedPreset

    ; A LavishScript Query used to scan a list of objects for matches, in this case where a name is empty (to filter out unused Window Presets)
    variable uint Query_NoName=${LavishScript.CreateQuery["Get[Name].Length==0"]}

    ; Object constructor
    method Initialize()
    {
        if ${JMB.Build}<6881
        {
            echo "WinEQ 2022 requires JMB build 6881 or later"
            return
        }

        ; Load our GUI
        LGUI2:LoadPackageFile[WEQ2022.Session.lgui2Package.json]

        ; Settings have already been imported from the INI file, just use our JSON copy
        Settings:ImportJSON
;        LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]            

        variable uint numPreset=1
        variable uint NumProfile

        ; WinEQ 2022 assigns the Character ID as Profile + 300, so reverse that to get the Profile number
        NumProfile:Set[${JMB.Character.ID}-300]

        ; now assuming we have a valid profile number, we will pull those settings
        if ${NumProfile}<=${Settings.Profiles.Size}
        {
            CurrentProfile:SetReference["Settings.Profiles[${NumProfile}]"]

            numPreset:Set[${CurrentProfile.Preset}+1]

            if ${CurrentProfile.GlobalHotkey.NotNULLOrEmpty} && ${CurrentProfile.GlobalHotkey.NotEqual["AUTO"]}
            {
                UseGlobalHotkey:Set["${CurrentProfile.GlobalHotkey~}"]
            }
            else
                UseGlobalHotkey:Set["${Settings.Hotkeys.Globals[${JMB.Slot.ID}]~}"]            
        }

        ; now assign the default preset...
        CurrentPreset:SetReference["Settings.Presets[${numPreset}]"]
        SelectedPreset:Set[${numPreset}]

        ; Register LavishScript events before attaching
;        LavishScript:RegisterEvent[OnWindowStateChanging]
;        LavishScript:RegisterEvent[On Window Position]
;        LavishScript:RegisterEvent[On Activate]
;        LavishScript:RegisterEvent[On Deactivate]
        LavishScript:RegisterEvent[On3DReset]
        

        ; Attach to LavishScript events
;        Event[OnWindowStateChanging]:AttachAtom[This:OnWindowStateChanging]
;        Event[On Window Position]:AttachAtom[This:OnWindowPosition]
;        Event[On Activate]:AttachAtom[This:OnActivate]
;        Event[On Deactivate]:AttachAtom[This:OnDeactivate]
        Event[On3DReset]:AttachAtom[This:On3DReset]

        if ${Settings.UseEQPlayNice}
        {
            EQPlayNice:SetCeiling["${Math.Calc[${Settings.RenderStrobeInterval}*1000]}"]
        }

        This:SetForegroundFPS[${Settings.ForegroundFPS}]
        This:SetBackgroundFPS[${Settings.BackgroundFPS}]        
        This:SetLockGamma[${Settings.LockGamma}]
        This:SetForceWindowed[${Settings.ForceWindowed}]

        if ${CurrentProfile.Adapter}>=0
        {
            This:SetForceAdapter[${CurrentProfile.Adapter}]
        }

        ; if the game window is already created, set it up as desired
        if ${Display.Window(exists)}
            This:SetupGameWindow
        else
            echo Game window not yet created

        ; for debugging purposes, I would uncomment the line below to see any output in the console.
;        LGUI2.Element[consolewindow]:SetVisibility[Visible]        
    }

    ; Object destructor
    method Shutdown()
    {
        ; shut down the Task Manager, ensuring that any hotkey we're still holding is effectively released
        TaskManager:Destroy

        ; uninstall Hotkeys
        This:UninstallHotkeys

        ; remove the Global Hotkey
        This:DisableGlobalHotkey
        
        ; unload our GUI
        LGUI2:UnloadPackageFile[WEQ2022.Session.lgui2Package.json]

        ; free our LavishScript Query
        LavishScript:FreeQuery[${Query_NoName}]
    }

    ; Process custom variables within a string, for example "WinEQ {VERSION} {PLUGIN} - EverQuest (Hotkey: {HOTKEY})" may become
    ; "WinEQ 2022 Joe Multiboxer Edition - EverQuest (Hotkey: Ctrl+Alt+1)"
	member:string ProcessVariables(string txt)
	{
		variable string Out
		variable string Var
;		echo ${txt}
		variable int brace
		variable int count

		brace:Set[${txt.Find["{"]}]

		while ${brace}>0
		{		
			count:Inc
			if ${count}>50
				break
;			echo brace=${brace}
			brace:Dec
			if ${brace}
			{
				Out:Concat["${txt.Left[${brace}]~}"]			

				txt:Set["${txt.Right[-${brace}]~}"]
			}

			brace:Set[${txt.Find["}"]}]
			if !${brace}
			{
				break
			}
			Var:Set["${txt.Left[${brace}]~}"]
			Var:Set["${Var.Mid[2,${Var.Length:Dec[2]}]~}"]
			txt:Set["${txt.Right[-${brace}]~}"]

            switch ${Var}
            {
            case HOTKEY
                Out:Concat["${UseGlobalHotkey~}"]
                break
            case PLUGIN
                Out:Concat["Joe Multiboxer Edition"]
                break
            case VERSION
                Out:Concat["2022"]
                break
            case SLOT
                Out:Concat["${JMB.Slot.ID}"]
                break
            case CHARACTER
                Out:Concat["${JMB.Character.DisplayName~}"]
                break
            case TEAM
                Out:Concat["${JMB.Team.DisplayName~}"]
                break
            default
                Out:Concat["{${Var~}}"]
                break
            }

;			echo Var=${Var~} Out=${Out~}   txt=${txt~}

			brace:Set[${txt.Find["{"]}]
		}

		Out:Concat["${txt~}"]

		return "${Out~}"
	}

    method OnWindowPosition()
    {
;        echo OnWindowPosition min=${Display.Window.IsMinimized} max=${Display.Window.IsMaximized} alwaysontop=${Display.Window.AlwaysOnTop} visible=${Display.Window.IsVisible}
    }

    method OnActivate()
    {
;        echo OnActivate
    }

    method OnDeactivate()
    {
;        echo OnDeactivate
    }

    ; Occurs when Direct3D is first ready for rendering, and also when it is later reset
    method On3DReset()
    {
;        echo On3DReset        
        variable bool priorState=${GameWindowSetup}
        GameWindowSetup:Set[FALSE]
        timed 3 "WEQ2022Session:SetupGameWindow[${priorState}]"
    }

    method OnWindowStateChanging(string newValue)
    {
        echo OnWindowStateChanging ${newValue~}
        switch ${newValue}
        {
            case SW_SHOW
                break
            case SW_HIDE
                break
        }
    }

    method SetForceAdapter(int numAdapter)
    {
        CurrentProfile.Adapter:Set[${numAdapter}]
        noop ${Direct3D8:SetAdapter[${numAdapter}]} ${Direct3D9:SetAdapter[${numAdapter}]} ${Direct3D11:SetMonitor["${Display.Monitor[${numAdapter.Inc}]~}"]}
    }

    method SetForceWindowed(bool value)
	{
        Settings.ForceWindowed:Set[${value}]
        noop ${Direct3D8:SetForceWindowed[${value}]} ${Direct3D9:SetForceWindowed[${value}]} ${Direct3D10:SetForceWindowed[${value}]} ${Direct3D11:SetForceWindowed[${value}]}				
	}

    method SetLockWindow(bool value)
    {
        Settings.LockWindow:Set[${value}]
        if ${value}
        {
            windowcharacteristics -lock
        }
        else
        {
            windowcharacteristics -unlock
        }
    }

    ; Installs a Hotkey, given a name, a key combination, and LavishScript code to execute on PRESS
    method InstallHotkey(string name, string keyCombo, string methodName)
    {
        variable jsonvalue joBinding
        ; initialize a LGUI2 input binding object with JSON
        joBinding:SetValue["$$>
        {
            "name":${name.AsJSON~},
            "combo":${keyCombo.AsJSON~},
            "eventHandler":{
                "type":"task",
                "taskManager":"weq2022Session",
                "task":{
                    "type":"ls1.code",
                    "start":${methodName.AsJSON~}
                }
            }
        }
        <$$"]

        ; now add the binding to LGUI2!
        LGUI2:AddBinding["${joBinding.AsJSON~}"]
    }

    ; Install non-global Hotkeys
    method InstallHotkeys()
    {
        if ${Settings.Hotkeys.ContextMenu.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ContextMenu,"${Settings.Hotkeys.ContextMenu~}","WEQ2022Session:OnHotkey_ContextMenu"]

        if ${Settings.Hotkeys.NextSession.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.NextSession,"${Settings.Hotkeys.NextSession~}","WEQ2022Session:OnHotkey_NextSession"]
        if ${Settings.Hotkeys.PrevSession.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.PrevSession,"${Settings.Hotkeys.PrevSession~}","WEQ2022Session:OnHotkey_PrevSession"]
        if ${Settings.Hotkeys.Duplicate.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.Duplicate,"${Settings.Hotkeys.Duplicate~}","WEQ2022Session:OnHotkey_Duplicate"]
        if ${Settings.Hotkeys.TogglePIPLock.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.TogglePIPLock,"${Settings.Hotkeys.TogglePIPLock~}","WEQ2022Session:OnHotkey_TogglePIPLock"]
        if ${Settings.Hotkeys.TogglePIP.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.TogglePIP,"${Settings.Hotkeys.TogglePIP~}","WEQ2022Session:OnHotkey_TogglePIP"]
        if ${Settings.Hotkeys.ToggleBorder.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ToggleBorder,"${Settings.Hotkeys.ToggleBorder~}","WEQ2022Session:OnHotkey_ToggleBorder"]
        if ${Settings.Hotkeys.ToggleTiling.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ToggleTiling,"${Settings.Hotkeys.ToggleTiling~}","WEQ2022Session:OnHotkey_ToggleTiling"]
        if ${Settings.Hotkeys.ToggleIndicator.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ToggleIndicator,"${Settings.Hotkeys.ToggleIndicator~}","WEQ2022Session:OnHotkey_ToggleIndicator"]
        if ${Settings.Hotkeys.ResetWindow.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ResetWindow,"${Settings.Hotkeys.ResetWindow~}","WEQ2022Session:OnHotkey_ResetWindow"]
        if ${Settings.Hotkeys.StoreWindow.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.StoreWindow,"${Settings.Hotkeys.StoreWindow~}","WEQ2022Session:OnHotkey_StoreWindow"]

        if ${Settings.Hotkeys.ShowGUI.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ShowGUI,"${Settings.Hotkeys.ShowGUI~}","WEQ2022Session:OnHotkey_ShowGUI"]
        if ${Settings.Hotkeys.ShowWindowPresets.NotNULLOrEmpty}
            This:InstallHotkey[weq2022.ShowWindowPresets,"${Settings.Hotkeys.ShowWindowPresets~}","WEQ2022Session:OnHotkey_ShowWindowPresets"]

        variable uint i
        for (i:Set[1] ; ${i}<=10 ; i:Inc)
        {
            if ${Settings.Hotkeys.Presets[${i}].NotNULLOrEmpty}
                This:InstallHotkey[weq2022.Preset${i},"${Settings.Hotkeys.Presets[${i}]~}","WEQ2022Session:OnHotkey_Preset[${i}]"]
        }
    }

    ; Uninstall non-global Hotkeys
    method UninstallHotkeys()
    {
        LGUI2:RemoveBinding["weq2022.ContextMenu"]
        LGUI2:RemoveBinding["weq2022.NextSession"]
        LGUI2:RemoveBinding["weq2022.PrevSession"]
        LGUI2:RemoveBinding["weq2022.Duplicate"]
        LGUI2:RemoveBinding["weq2022.TogglePIPLock"]
        LGUI2:RemoveBinding["weq2022.TogglePIP"]
        LGUI2:RemoveBinding["weq2022.ToggleBorder"]
        LGUI2:RemoveBinding["weq2022.ToggleTiling"]
        LGUI2:RemoveBinding["weq2022.ToggleIndicator"]
        LGUI2:RemoveBinding["weq2022.ResetWindow"]
        LGUI2:RemoveBinding["weq2022.StoreWindow"]
        LGUI2:RemoveBinding["weq2022.ShowGUI"]
        LGUI2:RemoveBinding["weq2022.ShowWindowPresets"]
        
        variable uint i
        for (i:Set[1] ; ${i}<=10 ; i:Inc)
        {
            LGUI2:RemoveBinding["weq2022.Preset${i}"]
        }
    }

    ; given a preset number, give us text to append to the name if it has a hotkey. e.g. "Normal (Shift+Alt+N)"
    member:string GetPresetHotkeyView(uint numPreset)
    {
        if !${Settings.Hotkeys.Presets[${numPreset}].NotNULLOrEmpty}
            return ""

        return " (${Settings.Hotkeys.Presets[${numPreset}]~})"
    }

    member:uint GetNextSlot()
    {
        variable uint Slot=${JMB.Slot}
        if !${Slot}
            return 0

        while 1
        {

            Slot:Inc
            if ${Slot}>${JMB.Slots.Used}
                Slot:Set[1]

            if ${Slot}==${JMB.Slot}
                return 0

            if ${JMB.Slot[${Slot}].ProcessID}
                return ${Slot}
        }        
    }

    member:uint GetPreviousSlot()
    {
        variable uint Slot=${JMB.Slot}
        if !${Slot}
            return 0

        while 1
        {

            Slot:Dec
            if !${Slot}
                Slot:Set[${JMB.Slots.Used}]

            if ${Slot}==${JMB.Slot}
                return 0

            if ${JMB.Slot[${Slot}].ProcessID}
                return ${Slot}
        }        
    }

    method PreviousWindow()
    {
        variable uint previousSlot=${This.GetPreviousSlot}
        if !${previousSlot}
            return

        if !${Display.Window.IsForeground}
            return

        uplink focus "jmb${previousSlot}"
        relay "jmb${previousSlot}" "Event[OnHotkeyFocused]:Execute"
    }

    method NextWindow()
    {
        variable uint nextSlot=${This.GetNextSlot}
        if !${nextSlot}
            return

        if !${Display.Window.IsForeground}
            return

        uplink focus "jmb${nextSlot}"
        relay "jmb${nextSlot}" "Event[OnHotkeyFocused]:Execute"
    }

    method OnSlotHotkey(uint numSlot)
    {
        uplink focus "jmb${numSlot}"
        relay "jmb${numSlot}" "Event[OnHotkeyFocused]:Execute"
    }

    method OnHotkey_Preset(uint numPreset)
    {
        echo OnHotkey_Preset[${numPreset}]
        This:SelectWindowPreset[${numPreset}]
    }

    method ShowPresetsWindow()
    {
        if ${LGUI2.Element[weq2022.PresetsWindow].Visibility.Name.Equal[Visible]}
        {
            LGUI2.Element[weq2022.PresetsWindow]:SetVisibility[Hidden]
        }
        else
            LGUI2.Element[weq2022.PresetsWindow]:SetVisibility[Visible]:BubbleToTop
    }

    method ShowGUI()
    {
        if ${LGUI2.Element[weq2022.ControlPanel].Visibility.Name.Equal[Visible]}
        {
            LGUI2.Element[weq2022.ControlPanel]:SetVisibility[Hidden]
        }
        else
        LGUI2.Element[weq2022.ControlPanel]:SetVisibility[Visible]:BubbleToTop
    }

    method OnHotkey_ShowGUI()
    {
        echo OnHotkey_ShowGUI
        This:ShowGUI
    }

    method OnHotkey_ShowWindowPresets()
    {
        echo OnHotkey_ShowWindowPresets
        This:ShowPresetsWindow
    }

    method OnHotkey_ContextMenu()
    {
        echo OnHotkey_ContextMenu
    }
    method OnHotkey_NextSession()
    {
        This:NextWindow
    }
    method OnHotkey_PrevSession()
    {
        This:PreviousWindow
    }
    method OnHotkey_Duplicate()
    {
        echo OnHotkey_Duplicate
    }
    method OnHotkey_TogglePIPLock()
    {
        echo OnHotkey_TogglePIPLock
    }
    method OnHotkey_TogglePIP()
    {
        echo OnHotkey_TogglePIP
    }
    method OnHotkey_ToggleBorder()
    {
        echo OnHotkey_ToggleBorder
    }
    method OnHotkey_ToggleTiling()
    {
        echo OnHotkey_ToggleTiling
    }
    method OnHotkey_ToggleIndicator()
    {
        echo OnHotkey_ToggleIndicator
    }
    method OnHotkey_ResetWindow()
    {
        echo OnHotkey_ResetWindow
    }
    method OnHotkey_StoreWindow()
    {
        echo OnHotkey_StoreWindow
    }

    ; set up the game window -- assign positions, hotkeys, etc
    method SetupGameWindow(bool priorState)
    {   
        ; if it's already set up, don't just do it again for no reason. (when the window resets, however, we will clear this variable)
        if ${GameWindowSetup}
            return

        ; if the game window isn't created yet, we can't continue yet.
        if !${Display.Window(exists)}
            return

        This:SetLockWindow[${Settings.LockWindow}]

        echo "Performing game window setup ..."

        echo "Current Profile: ${CurrentProfile.AsJSON~}"

        This:ApplyGlobalHotkey
        This:ApplyWindowText
        This:InstallHotkeys

        if !${priorState}
            This:ApplyWindowPreset

        GameWindowSetup:Set[1]
    }

    method DisableGlobalHotkey()
    {
        globalbind -delete weq2_activate
    }

    method ApplyGlobalHotkey()
    {
        This:DisableGlobalHotkey
        globalbind weq2_activate "${UseGlobalHotkey}" "WEQ2022Session:OnGlobalHotkey"
    }

    method OnGlobalHotkey()
    {
        echo OnGlobalHotkey
        WindowVisibility foreground
    }

    ; applies our custom window text
    method ApplyWindowText()
    {
        ; maybe we dont want custom window text
        if !${CurrentProfile.WindowText.NotNULLOrEmpty}
            return
        
        ; looks like we do. it might have variables like {HOTKEY} {PLUGIN} etc. process those first
        windowtext "${This.ProcessVariables["${CurrentProfile.WindowText~}"]~}"
    }

    ; selects and applies a window preset, by number
    method SelectWindowPreset(uint newValue)
    {
        SelectedPreset:Set[${newValue}]
        CurrentPreset:SetReference["Settings.Presets[${newValue}]"]
        This:ApplyWindowPreset
    }

    method SetUseEQPlayNice(bool newValue)
    {
        echo SetUseEQPlayNice ${newValue}
        Settings.UseEQPlayNice:Set[${newValue}]
        if ${newValue}
        {
            EQPlayNice:Enable
            EQPlayNice:SetCeiling["${Math.Calc[${Settings.RenderStrobeInterval}*1000]}"]
        }
        else
        {
            EQPlayNice:Disable
        }
    }

    method SetRenderStrobeInterval(float newValue)
    {
        echo SetRenderStrobeInterval ${newValue}
        Settings.RenderStrobeInterval:Set[${newValue}]
        EQPlayNice:SetCeiling["${Math.Calc[${newValue}*1000]}"]
    }

    method SetLockGamma(bool newValue)
    {
        echo SetLockGamma ${newValue}
        Settings.LockGamma:Set[${newValue}]
        if ${newValue}
            GammaLock on
        else
            GammaLock off
    }

    method SetForegroundFPS(uint newValue)
    {
        echo SetForegroundFPS ${newValue}
        Settings.ForegroundFPS:Set[${newValue}]

        if ${newValue}
            maxfps -fg -calculate ${newValue}
        else
            maxfps -fg -disable
    }

    method SetBackgroundFPS(uint newValue)
    {
        echo SetBackgroundFPS ${newValue}
        Settings.BackgroundFPS:Set[${newValue}]

        if ${newValue}
            maxfps -bg -calculate ${newValue}
        else
            maxfps -bg -disable
    }

    ; applies the current window preset
    method ApplyWindowPreset()
    {  
           ; make sure the game window currently exists, otherwise we have nothing to do yet
        if !${Display.Window(exists)} || !${Display.Width} || !${Display.Height}
            return

         ;   windowscale 100
        ; make sure we HAVE a current window preset
        if !${CurrentPreset.Reference(exists)}
        {
            return
        }
        echo "Applying Window Preset ${CurrentPreset.Name~}"
        echo "${CurrentPreset.AsJSON~}"

        variable int monitorX=${Display.Monitor.Left}
        variable int monitorY=${Display.Monitor.Top}

        if ${CurrentProfile.Adapter}>=0 && ${Display.Monitor[${CurrentProfile.Adapter.Inc}](exists)}
        {
            monitorX:Set[${Display.Monitor[${CurrentProfile.Adapter.Inc}].Left}]
            monitorY:Set[${Display.Monitor[${CurrentProfile.Adapter.Inc}].Top}]
        }

        if ${CurrentPreset.FullScreen}
        {
            ; full screen! note that the 0,0 position used here is the primary display.
            WindowCharacteristics -stealth -size -viewable fullscreen -pos -viewable ${monitorX},${monitorY} -frame none -visibility foreground
            return
        }

        ; if not fullscreen, we might want to adjust Always On Top and the border...
        variable string useAlwaysOnTop
        if ${CurrentPreset.AlwaysOnTop}
            useAlwaysOnTop:Set[" -visibility -noactivate alwaysontop"]
        else
            useAlwaysOnTop:Set[" -visibility foreground"]

        variable string useBorder=" -frame none"
        if ${CurrentPreset.Border}
        {
            if ${CurrentPreset.LockSize}
                useBorder:Set[" -frame thin"]
            else
                useBorder:Set[" -frame thick"]
        }

        variable uint sizeX
        variable uint sizeY

        ; Apply desired scaling using the game's 3D width/height
        variable float useScale=${CurrentPreset.Scale}

        ; if scale is set to 0 we should probably treat that as one of a) unintended, b) intended to use a default value, or c) it has not been set at all.
        if ${useScale}<0.01
            useScale:Set[1.0]

        sizeX:Set[${Display.Width}*${useScale}]
        sizeY:Set[${Display.Height}*${useScale}]

        variable int posX
        variable int posY
        posX:Set[${monitorX}+${CurrentPreset.X}]
        posY:Set[${monitorY}+${CurrentPreset.Y}]

        if ${useScale}!=1.0
            WindowCharacteristics -stealth -pos -viewable ${posX},${posY} -size -viewable ${sizeX}x${sizeY} ${useAlwaysOnTop}${useBorder}
        else
            WindowCharacteristics -pos -viewable ${posX},${posY} -size -viewable ${sizeX}x${sizeY} ${useAlwaysOnTop}${useBorder}
        
    }

    ; Used by the GUI, sets the selected preset in the list box
    method SetSelectedPreset(uint numPreset)
    {
;        echo SetSelectedPreset ${numPreset}
        SelectedPreset:Set[${numPreset}]
    }

    ; Used by the GUI, applies the preset selected in the list box
    method ApplySelectedPreset()
    {
        This:SelectWindowPreset[${SelectedPreset}]
    }

    ; generate a listbox view of a preset
    method GenerateItemView_Preset()
	{
       ; echo GenerateItemView_Preset ${Context(type)} ${Context.Args}

		; build an itemview lgui2element json
		variable jsonvalue joListBoxItem

        ; here we use the "weq2022.presetView" template defined in our LGUI2 package file 
		joListBoxItem:SetValue["${LGUI2.Template["weq2022.presetView"].AsJSON~}"]
        
        ; and set the view!
		Context:SetView["${joListBoxItem.AsJSON~}"]
	}

    ; used by the GUI to list presets, returns a JSON array of Window Presets that have a name
    member:string ActivePresets()
    {
        variable jsonvalue ja="${Settings.Presets.AsJSON~}"

        ja:EraseByQuery["${Query_NoName}"]
;        echo ActivePresets=${ja.AsJSON}
        return "${ja~}"
    }
}

variable(global) weq2022session WEQ2022Session

function main()
{
    while 1
        waitframe
}