; Object used to import and manage WinEQ 2 settings
objectdef weq2settings
{
    variable bool UseIndicator=TRUE
    variable int IndicatorX=20
    variable int IndicatorY=28
    variable bool LockGamma=FALSE
    variable bool UseEQPlayNice=FALSE
    variable float RenderStrobeInterval=1.0
    variable filepath AgentFolder="${Script.CurrentDirectory~}"
    variable string Version="${JMB.Agent[WinEQ 2022].Version~}"

    variable uint ForegroundFPS=60
    variable uint BackgroundFPS=60

    variable index:weq2profile Profiles
    variable index:weq2preset Presets
    variable weq2hotkeys Hotkeys

    method Initialize()
    {
        Presets:Resize[10]
        Profiles:Resize[30]
    }

    ; Generate a JSON snapshot
    member AsJSON()
    {
        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "Indicator":${UseIndicator.AsJSON~},
            "IndicatorX":${IndicatorX.AsJSON~},
            "IndicatorY":${IndicatorY.AsJSON~},
            "LockGamma":${LockGamma.AsJSON~},
            "EQPlayNice":${UseEQPlayNice.AsJSON~},
            "RenderStrobeInterval":${RenderStrobeInterval.AsJSON~},
            "BackgroundFPS":${BackgroundFPS.AsJSON~},
            "ForegroundFPS":${ForegroundFPS.AsJSON~},
            "Hotkeys":${Hotkeys.AsJSON~}
        }
        <$$"]

        variable int i
        for (i:Set[1] ; ${i}<= 30 ; i:Inc)
        {
            if ${Profiles[${i}].Name.NotNULLOrEmpty}
                jo:Set[Profile${i},"${This.Profiles[${i}].AsJSON~}"]
        }
        for (i:Set[1] ; ${i}<= 10 ; i:Inc)
        {
            jo:Set[Preset${i},"${This.Presets[${i}].AsJSON~}"]
        }

        return "${jo.AsJSON~}"
    }

    ; Given a JSON snapshot, fill in all of our variables
    method FromJSON(jsonvalueref joRoot)
    {
 ;       echo "weq2settings:FromJSON[${joRoot~}]"
        variable jsonvalueref jo
        variable int i

        jo:SetReference["joRoot.Get[General]"]
        if !${jo.Reference(exists)}
        {
            jo:SetReference[joRoot]
        }

        if ${jo.Has[Indicator]}
            UseIndicator:Set["${jo.Get[Indicator]~}"]

        if ${jo.Has[IndicatorX]}
            IndicatorX:Set["${jo.Get[IndicatorX]~}"]

        if ${jo.Has[IndicatorY]}
            IndicatorY:Set["${jo.Get[IndicatorY]~}"]

        if ${jo.Has[LockGamma]}
            LockGamma:Set["${jo.Get[LockGamma]~}"]

        if ${jo.Has[EQPlayNice]}
            UseEQPlayNice:Set["${jo.Get[EQPlayNice]~}"]

        if ${jo.Has[RenderStrobeInterval]}
            RenderStrobeInterval:Set["${jo.Get[RenderStrobeInterval]~}"]

        if ${jo.Has[ForegroundFPS]}
            ForegroundFPS:Set["${jo.Get[ForegroundFPS]~}"]
        if ${jo.Has[BackgroundFPS]}
            BackgroundFPS:Set["${jo.Get[BackgroundFPS]~}"]


        jo:SetReference["joRoot.Get[Hotkeys]"]
        if ${jo.Reference(exists)}
        {
            Hotkeys:FromJSON[jo]
        }

        for (i:Set[1] ; ${i}<= 30 ; i:Inc)
        {
            jo:SetReference["joRoot.Get[Profile${i}]"]
            if ${jo.Reference(exists)}
            {
                This.Profiles:Set[${i},"${i}"]
                This.Profiles[${i}]:FromJSON[jo]
            }
        }

        for (i:Set[1] ; ${i}<= 10 ; i:Inc)
        {
            jo:SetReference["joRoot.Get[Preset${i}]"]
            if ${jo.Reference(exists)}
            {
                This.Presets:Set[${i},"${i}"]
                This.Presets[${i}]:FromJSON[jo]
            }
        }

        ; inform the GUI that we have updated our list of profiles
        LGUI2.Element[weq2022.events]:FireEventHandler[onProfilesUpdated]
    }

    ; Determine if our settings file exists
    member:bool SettingsFileExists()
    {
        return ${AgentFolder.FileExists[WinEQ2022.Settings.json]}
    }

    ; Import settings from our JSON settings file
    method ImportJSON()
    {
        variable jsonvalue jo

        if !${jo:ParseFile["${Script.CurrentDirectory~}/WinEQ2022.Settings.json"](exists)} || !${jo.Type.Equal[object]}
            return FALSE

        This:FromJSON[jo]
        return TRUE
    }

    ; Export settings to our JSON settings file
    method ExportJSON()
    {
        variable jsonvalue jo
        jo:SetValue["${This.AsJSON~}"]
        if !${jo.Type.Equal[object]}
            return FALSE

        jo:WriteFile["${Script.CurrentDirectory~}/WinEQ2022.Settings.json",multiline]
        return TRUE
    }

    ; Import settings from WinEQ 2's wineq2-eq.ini file
    method ImportINI(string filename)
    {
        variable jsonvalue jo="{}"
        if !${jo:ParseINIFile["${filename~}"](exists)} || !${jo.Type.Equal[object]}
            return FALSE

  ;      echo "ImportINI retrieved ${jo~}"
        This:FromJSON[jo]

        return TRUE
    }
}

; WinEQ 2 Hotkeys section
objectdef weq2hotkeys
{
    variable string ContextMenu
    variable string NextSession
    variable string PrevSession
    variable string Duplicate
    variable string TogglePIPLock
    variable string TogglePIP
    variable string ToggleBorder
    variable string ToggleTiling
    variable string ToggleIndicator
    variable string ResetWindow
    variable string StoreWindow
    variable string ShowGUI="Ctrl+Shift+Alt+G"
    variable string ShowWindowPresets="Ctrl+Shift+Alt+P"
    variable index:string Presets
    variable index:string Globals

    method Initialize()
    {
        Presets:Resize[10]
        Globals:Resize[10]
    }

    ; Converts a WinEQ 2 key combo like "Shift+RButton" to a JMB format like "Shift+Mouse1"
    member:string ConvertKeyCombo(string keyCombo)
    {
        return "${keyCombo.ReplaceSubstring["LButton","Mouse1"].ReplaceSubstring["RButton","Mouse2"].ReplaceSubstring["MButton","Mouse3"].ReplaceSubstring["XButton1","Mouse4"].ReplaceSubstring["XButton2","Mouse5"]~}"
    }

    ; Given a JSON snapshot, fill in all of our variables
    method FromJSON(jsonvalueref jo)
    {
        variable int i
;        echo "Hotkeys:FromJSON[${jo~}]"

        if ${jo.Has["ContextMenu"]}
            ContextMenu:Set["${This.ConvertKeyCombo["${jo.Get[ContextMenu]~}"]~}"]

        if ${jo.Has["NextSession"]}
            NextSession:Set["${This.ConvertKeyCombo["${jo.Get[NextSession]~}"]~}"]
        if ${jo.Has["PrevSession"]}
            PrevSession:Set["${This.ConvertKeyCombo["${jo.Get[PrevSession]~}"]~}"]
        if ${jo.Has["Duplicate"]}
            Duplicate:Set["${This.ConvertKeyCombo["${jo.Get[Duplicate]~}"]~}"]
        if ${jo.Has["TogglePIPLock"]}
            TogglePIPLock:Set["${This.ConvertKeyCombo["${jo.Get[TogglePIPLock]~}"]~}"]

        if ${jo.Has["TogglePIP"]}
            TogglePIP:Set["${This.ConvertKeyCombo["${jo.Get[TogglePIP]~}"]~}"]
        if ${jo.Has["ToggleBorder"]}
            ToggleBorder:Set["${This.ConvertKeyCombo["${jo.Get[ToggleBorder]~}"]~}"]
        if ${jo.Has["ToggleTiling"]}
            ToggleTiling:Set["${This.ConvertKeyCombo["${jo.Get[ToggleTiling]~}"]~}"]
        if ${jo.Has["ToggleIndicator"]}
            ToggleIndicator:Set["${This.ConvertKeyCombo["${jo.Get[ToggleIndicator]~}"]~}"]
        if ${jo.Has["ResetWindow"]}
            ResetWindow:Set["${This.ConvertKeyCombo["${jo.Get[ResetWindow]~}"]~}"]

        if ${jo.Has["StoreWindow"]}
            StoreWindow:Set["${This.ConvertKeyCombo["${jo.Get[StoreWindow]~}"]~}"]

        if ${jo.Has["ShowGUI"]}
            ShowGUI:Set["${This.ConvertKeyCombo["${jo.Get[ShowGUI]~}"]~}"]
        if ${jo.Has["ShowWindowPresets"]}
            ShowWindowPresets:Set["${This.ConvertKeyCombo["${jo.Get[ShowWindowPresets]~}"]~}"]

        for (i:Set[1] ; ${i}<=10 ; i:Inc)
        {
            if ${jo.Has["Preset${i}"]}
                Presets:Set[${i},"${This.ConvertKeyCombo["${jo.Get[Preset${i}]~}"]~}"]
            if ${jo.Has["Global${i}"]}
                Globals:Set[${i},"${This.ConvertKeyCombo["${jo.Get[Global${i}]~}"]~}"]
        }
    }

    ; Generate a JSON snapshot
    member AsJSON()
    {
        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "ContextMenu":${ContextMenu.AsJSON~},
            "NextSession":${NextSession.AsJSON~},
            "PrevSession":${PrevSession.AsJSON~},
            "Duplicate":${Duplicate.AsJSON~},
            "TogglePIPLock":${TogglePIPLock.AsJSON~},
            "TogglePIP":${TogglePIP.AsJSON~},
            "ToggleBorder":${ToggleBorder.AsJSON~},
            "ToggleTiling":${ToggleTiling.AsJSON~},
            "ToggleIndicator":${ToggleIndicator.AsJSON~},
            "ResetWindow":${ResetWindow.AsJSON~},
            "StoreWindow":${StoreWindow.AsJSON~},
            "ShowGUI":${ShowGUI.AsJSON~},
            "ShowWindowPresets":${ShowWindowPresets.AsJSON~}
        }
        <$$"]

        variable int i
        for (i:Set[1] ; ${i}<= 10 ; i:Inc)
        {
            jo:Set[Preset${i},"${This.Presets[${i}].AsJSON~}"]
            jo:Set[Global${i},"${This.Globals[${i}].AsJSON~}"]
        }

        return "${jo.AsJSON~}"
    }

    /*
    "Hotkeys": {
        "ContextMenu": "Shift+RButton",
        "NextSession": "Ctrl+Alt+X",
        "PrevSession": "Ctrl+Alt+Z",
        "Duplicate": "Ctrl+Alt+N",
        "TogglePIPLock": "Ctrl+Alt+O",
        "TogglePIP": "Ctrl+Alt+P",
        "ToggleBorder": "Ctrl+=",
        "ToggleTiling": "Ctrl+\\",
        "ToggleIndicator": "Ctrl+Alt+M",
        "ResetWindow": "Shift+Alt+R",
        "Release": "NONE",
        "StoreWindow": "Ctrl+Alt+S",
        "Preset1": "Shift+Alt+N",
        "Preset2": "Shift+Alt+T",
        "Preset3": "Shift+Alt+F",
        "Preset4": "NONE",
        "Preset5": "NONE",
        "Preset6": "NONE",
        "Preset7": "NONE",
        "Preset8": "NONE",
        "Preset9": "NONE",
        "Preset10": "NONE",
        "Capture": "NONE",
        "Global1": "Ctrl+Alt+1",
        "Global2": "Ctrl+Alt+2",
        "Global3": "Ctrl+Alt+3",
        "Global4": "Ctrl+Alt+4",
        "Global5": "Ctrl+Alt+5",
        "Global6": "Ctrl+Alt+6",
        "Global7": "Ctrl+Alt+7",
        "Global8": "Ctrl+Alt+8"
    },
     */
}

; A WinEQ 2 Profile
objectdef weq2profile
{
    variable string Name
    variable string WindowText
    variable string GlobalHotkey="AUTO"
    variable filepath EQPath
    variable string EQClientINI=".\\eqclient.ini"
    variable int Preset
    variable int Locale
    variable int Adapter=-1
    variable bool Sound=TRUE
    variable bool Patch=TRUE
    variable bool TestServer=FALSE
    variable int Tile
    variable float FGTileScale=0.6
    variable float BGTileScale=0.5
    variable bool PIP
    variable int PIPX=20
    variable int PIPY=20
    variable bool PIPBorder
    variable float PIPScale=0.2

    variable uint NumProfile
    variable string UseGame

    method Initialize(uint numProfile)
    {
        NumProfile:Set[${numProfile}]
    }

    ; Given a JSON snapshot, fill in all of our variables
    method FromJSON(jsonvalueref jo)
    {
 ;       echo "Profile:FromJSON[${jo~}]"

        if ${jo.Has["Name"]}
            Name:Set["${jo.Get[Name]~}"]
        if ${jo.Has["WindowText"]}
            WindowText:Set["${jo.Get[WindowText]~}"]
        if ${jo.Has["GlobalHotkey"]}
            GlobalHotkey:Set["${jo.Get[GlobalHotkey]~}"]
        if ${jo.Has["EQPath"]}
            EQPath:Set["${jo.Get[EQPath]~}"]
        if ${jo.Has["EQClientINI"]}
            EQClientINI:Set["${jo.Get[EQClientINI]~}"]
        if ${jo.Has["Preset"]}
            Preset:Set["${jo.Get[Preset]~}"]
        if ${jo.Has["Locale"]}
            Locale:Set["${jo.Get[Locale]~}"]
        if ${jo.Has["Adapter"]}
            Adapter:Set["${jo.Get[Adapter]~}"]
        if ${jo.Has["Sound"]}
            Sound:Set["${jo.Get[Sound]~}"]
        if ${jo.Has["Patch"]}
            Patch:Set["${jo.Get[Patch]~}"]
        if ${jo.Has["TestServer"]}
            TestServer:Set["${jo.Get[TestServer]~}"]
        if ${jo.Has["Tile"]}
            Tile:Set["${jo.Get[Tile]~}"]
        if ${jo.Has["FGTileScale"]}
            FGTileScale:Set["${jo.Get[FGTileScale]~}"]
        if ${jo.Has["BGTileScale"]}
            BGTileScale:Set["${jo.Get[BGTileScale]~}"]
        if ${jo.Has["PIP"]}
            PIP:Set["${jo.Get[PIP]~}"]
        if ${jo.Has["PIPX"]}
            PIPX:Set["${jo.Get[PIPX]~}"]
        if ${jo.Has["PIPY"]}
            PIPY:Set["${jo.Get[PIPY]~}"]
        if ${jo.Has["PIPBorder"]}
            PIPBorder:Set["${jo.Get[PIPBorder]~}"]
        if ${jo.Has["PIPScale"]}
            PIPScale:Set["${jo.Get[PIPScale]~}"]
        if ${jo.Has["UseGame"]}
            UseGame:Set["${jo.Get[UseGame]~}"]
    }

    ; Generate a JSON snapshot
     member AsJSON()
    {
        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "Name":${Name.AsJSON~},
            "WindowText":${WindowText.AsJSON~},
            "GlobalHotkey":${GlobalHotkey.AsJSON~},
            "EQPath":${EQPath.AsJSON~},
            "EQClientINI":${EQClientINI.AsJSON~},
            "Preset":${Preset.AsJSON~},
            "Locale":${Locale.AsJSON~},
            "Adapter":${Adapter.AsJSON~},
            "Sound":${Sound.AsJSON~},
            "Patch":${Patch.AsJSON~},
            "TestServer":${TestServer.AsJSON~},
            "Tile":${Tile.AsJSON~},
            "FGTileScale":${FGTileScale.AsJSON~},
            "BGTileScale":${BGTileScale.AsJSON~},
            "PIP":${PIP.AsJSON~},
            "PIPX":${PIPX.AsJSON~},
            "PIPY":${PIPY.AsJSON~},
            "PIPBorder":${PIPBorder.AsJSON~},
            "PIPScale":${PIPScale.AsJSON~},
            "UseGame":${UseGame.AsJSON~},
            "NumProfile":${NumProfile.AsJSON~},
        }
        <$$"]
        return "${jo.AsJSON~}"
    }

    /*
        "Profile1": {
        "Name": "WinEQ 2.0 Default Profile",
        "WindowText": "WinEQ {VERSION} {PLUGIN} - EverQuest (Hotkey: {HOTKEY})",
        "GlobalHotkey": "AUTO",
        "EQPath": "c:\\users\\public\\sony online entertainment\\installed games\\everquest",
        "EQClientINI": ".\\eqclient.ini",
        "Preset": 0,
        "Locale": 0,
        "Adapter": -1,
        "Sound": 1,
        "Patch": 0,
        "TestServer": 0,
        "Tile": -1,
        "FGTileScale": 0.60,
        "BGTileScale": 0.50,
        "PIP": 0,
        "PIPX": 20,
        "PIPY": 20,
        "PIPBorder": 0,
        "PIPScale": 0.20
    },
    */
}

; A WinEQ 2 Window Preset
objectdef weq2preset
{
    variable string Name
    variable int X
    variable int Y
    variable bool FullScreen
    variable bool AlwaysOnTop
    variable bool LockPosition
    variable bool LockSize
    variable bool Border
    variable float Scale=1.0

    variable uint NumPreset
    method Initialize(uint numPreset)
    {
        NumPreset:Set[${numPreset}]
    }

    ; Given a JSON snapshot, fill in all of our variables
    method FromJSON(jsonvalueref jo)
    {
 ;       echo "Preset:FromJSON[${jo~}]"

        if ${jo.Has["Name"]}
            Name:Set["${jo.Get[Name]~}"]

        if ${jo.Has["X"]}
            X:Set["${jo.Get[X]~}"]
        if ${jo.Has["Y"]}
            Y:Set["${jo.Get[Y]~}"]
        if ${jo.Has["FullScreen"]}
            FullScreen:Set["${jo.Get[FullScreen]~}"]
        if ${jo.Has["AlwaysOnTop"]}
            AlwaysOnTop:Set["${jo.Get[AlwaysOnTop]~}"]
        if ${jo.Has["LockPosition"]}
            LockPosition:Set["${jo.Get[LockPosition]~}"]
        if ${jo.Has["LockSize"]}
            LockSize:Set["${jo.Get[LockSize]~}"]
        if ${jo.Has["Border"]}
            Border:Set["${jo.Get[Border]~}"]
        if ${jo.Has["Scale"]}
            Scale:Set["${jo.Get[Scale]~}"]
    }

    method SetName(string newValue)
    {
        Name:Set["${newValue~}"]
        ; inform the GUI that we have updated our list of profiles
        LGUI2.Element[weq2022.events]:FireEventHandler[onPresetsUpdated]
    }

    ; Generate a one-line summary of the preset
    member:string Summary()
    {
        variable string output="@${X},${Y} ${Math.Calc[${Scale}*100].Int}%"

        if ${FullScreen}
            output:Concat[" (Full Screen)"]
        if ${AlwaysOnTop}
            output:Concat[" (Always On Top)"]
        if !${Border}
            output:Concat[" (No Border)"]

        return "${output~}"
    }

    ; Generate a JSON snapshot
  member AsJSON()
    {
        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "Name":${Name.AsJSON~},
            "X":${X.AsJSON~},
            "Y":${Y.AsJSON~},
            "AlwaysOnTop":${AlwaysOnTop.AsJSON~},
            "FullScreen":${FullScreen.AsJSON~},
            "LockPosition":${LockPosition.AsJSON~},
            "LockSize":${LockSize.AsJSON~},
            "Border":${Border.AsJSON~},
            "Scale":${Scale.AsJSON~},
            "NumPreset":${NumPreset.AsJSON~},
            "Summary":${This.Summary.AsJSON~}
        }
        <$$"]
        return "${jo.AsJSON~}"
    }
    /* 
     "Preset1": {
        "Name": "Normal",
        "X": 0,
        "Y": 15,
        "FullScreen": 0,
        "AutoRelease": 0,
        "AlwaysOnTop": 0,
        "LockPosition": 0,
        "LockSize": 0,
        "Border": 1,
        "Scale": 1.0
    },
    */
}
