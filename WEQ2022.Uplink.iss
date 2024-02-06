#include "WEQ2.Settings.iss"

; controller for WinEQ 2022 in the Joe Multiboxer Uplink (main program)
objectdef weq2022
{
    ; the WinEQ 2 settings object
    variable weq2settings Settings

    ; the WinEQ 2 folder to use
    variable string WinEQ2Folder="C:\\Program Files (x86)\\WinEQ2"

    ; Reference to the currently selected Profile
    variable weakref UseProfile

    ; Reference to the currently selected Window Preset
    variable weakref SelectedPreset

    ; Object constructor
    method Initialize()
    {
        variable filepath fpFolder="${WinEQ2Folder~}"
        
        if ${JMB.Build}<6881
        {
            echo "WinEQ 2022 requires JMB build 6881 or later"
            return
        }
        
        ; Load our GUI
        LGUI2:LoadPackageFile[WEQ2022.Uplink.lgui2Package.json]
        This:AddAgentProvider

        LGUI2.Element[weq2022.MainWindow]:SetTitle["\"WinEQ 2022 Joe Multiboxer Edition v${Settings.Version}\""]

        ; If our JSON settings file does not exist, we should offer to provide defaults or allow the user to import from WinEQ 2
        if !${Settings.SettingsFileExists}
        {
            ; first run
            MainWindow -show
            LGUI2.Element[weq2022.FirstRun]:SetVisibility[Visible]:BubbleToTop

            if !${fpFolder.FileExists[wineq-eq.ini]}
            {
                ; nope
                LGUI2.Element[weq2022.FirstRun.NotFound]:SetText["WinEQ 2 not found in ${WEQ2022.WinEQ2Folder~}"]:SetVisibility[Visible]                
                return
            }

        }
        else
        {
            ; not first run
            Settings:ImportJSON
            This:InstallEQFolders
            LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]:BubbleToTop
        }

        This:SetProfile["WinEQ 2.0 Default Profile"]
        This:SelectPreset[1]
        This:InstallMenu
    }

    ; Object destructor
    method Shutdown()
    {
        This:RemoveAgentProvider
        LGUI2:UnloadPackageFile[WEQ2022.Uplink.lgui2Package.json]
    }

    ; Given a profile number, get a Character ID to use
    member:uint GetCharacterID(uint NumProfile)
    {
        return ${NumProfile:Inc[300]}
    }

    ; Given a profile number, install a Joe Multiboxer Character for that profile
    method InstallCharacter(uint NumProfile)
    {
        variable weakref useProfile="Settings.Profiles[${NumProfile}]"

        ; name of the JMB "Game"
        variable string gamePath="${useProfile.EQPath~}"
        variable string gameExecutable="${useProfile.GetExecutable~}"
        variable string parameters="${useProfile.GetParameters~}"
        
        ; the Character ID to add
        variable uint CharacterID=${This.GetCharacterID[${NumProfile}]}

        ; the Character Name will be the name of the profile 
        variable string CharacterName="${useProfile.Name~}"

        ; add custom eqclient.ini file if specified
        ; note that the default value from WinEQ 2 is ".\eqclient.ini" and that slash should be converted to a / to make things easier
        variable string EQClientINI="${useProfile.EQClientINI.Replace["\\","/"]~}"
        if !${EQClientINI.NotNULLOrEmpty}
            EQClientINI:Set["eqclient.ini"]

        variable uint eqlsFileNumber
        if ${NumProfile}>0
            eqlsFileNumber:Set[${NumProfile}-1]

        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "id":${CharacterID},
            "display_name":${CharacterName.AsJSON~},
            "path":${gamePath.AsJSON~},
            "executable":${gameExecutable.AsJSON~},
            "parameters":${parameters.AsJSON~},
            "virtualFiles":[
                {
                    "pattern":"*\/eqclient.ini",
                    "replacement":"{1}/${EQClientINI~}"
                },
                {
                    "pattern":"*\/eqlsPlayerData.ini",
                    "replacement":"{1}/eqlsPlayerData.WinEQProfile${eqlsFileNumber}.ini"
                }
            ]
        }
        <$$"]

;        echo "adding character ${jo.AsJSON~}"
        JMB:AddCharacter["${jo.AsJSON~}"]
    }

    method OnMainWindowCommand()
    {
        MainWindow -show

        switch ${LGUI2.Element[weq2022.firstRun].Visibility}
        {
            case Visible
                LGUI2.Element[weq2022.firstRun]:BubbleToTop
                break
            default
                LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]:BubbleToTop
                break
        }        
    }



    ; install WinEQ 2022 sub-menu in the Joe Multiboxer right-click menu
    method InstallMenu()
    {
        ISMenu.FindChild["WinEQ 2022"]:Remove

        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "name":"WinEQ 2022",
            "type":"submenu",
            "items":[
                {
                    "name":"Main Window",
                    "type":"command",
                    "command":"WEQ2022:OnMainWindowCommand"
                },
                {
                    "name":"Launch",
                    "type":"submenu",
                    "items":${This.GetProfileMenuItems.AsJSON~}
                }
            ]
        }
        <$$"]

        ISMenu:AddFromJSON["${jo.AsJSON~}"]
    }

    ; Generates Joe Multiboxer menu items for launching each profile
    member:jsonvalueref GetProfileMenuItems()
    {
        variable jsonvalue ja="[]"

        variable int i
        for (i:Set[1] ; ${i}<=30 ; i:Inc)
        {
            if ${Settings.Profiles[${i}].Name.NotNULLOrEmpty}
            {
                ja:Add["${This.GetProfileMenuItem[${i}]~}"]
            }
        }

        return ja
    }

    ; Generates a Joe Multiboxer menu item to launch a specific profile
    member:jsonvalueref GetProfileMenuItem(uint numProfile)
    {
        variable string useName="${Settings.Profiles[${numProfile}].Name~}" 
        variable string useCommand="WEQ2022:OnLaunchProfileCommand[${numProfile}]"
        variable jsonvalue jo
        jo:SetValue["$$>
                {
                    "name":${useName.AsJSON~},
                    "type":"command",
                    "command":${useCommand.AsJSON~}
                }
                <$$"]
        return jo
    }

    ; Find a Slot that does not currently have a running game instance 
    member:uint FindEmptySlot()
    {
        variable jsonvalueref currentSlots="JMB.Slots"
        variable uint i
        for (i:Set[1] ; ${i} <= ${currentSlots.Used} ; i:Inc)
        {
            if !${currentSlots.Get[${i},"processId"]}
            {
                return ${i}
            }
        }
        return 0
    }

    method OnDeleteProfileButton()
    {
        variable uint NumProfile=${UseProfile.NumProfile}
        if !${NumProfile}
        {
            ; no profile selected
            echo UseProfile.NumProfile = ${NumProfile}
            return
        }

        Settings.Profiles:Remove[${NumProfile}]
        LGUI2.Element[weq2022.events]:FireEventHandler[onProfilesUpdated]
    }

    method OnNewProfileButton()
    {
        variable uint NumProfile = ${Settings.Profiles.Used.Inc}


        variable jsonvalueref joNewProfile

        variable uint copyProfile=${UseProfile.NumProfile}
        if !${copyProfile} && ${Settings.Profiles[1](exists)}
        {
            copyProfile:Set[1]
        }

        if ${copyProfile}
        {
            joNewProfile:SetReference["Settings.Profiles[1].AsJSON.Duplicate"]
        }

        if !${joNewProfile.Reference(exists)}        
            joNewProfile:SetReference["{}"]

        joNewProfile:SetString[Name,"WinEQ 2022 Profile ${NumProfile}"]

        Settings.Profiles:Insert[${NumProfile},${NumProfile}]

        Settings.Profiles[${NumProfile}]:FromJSON[joNewProfile]
        LGUI2.Element[weq2022.events]:FireEventHandler[onProfilesUpdated]
    }

    method OnCreateShortcutButton()
    {
        variable uint NumProfile=${UseProfile.NumProfile}
        if !${NumProfile}
        {
            ; no profile selected
            echo UseProfile.NumProfile = ${NumProfile}
            return
        }

        This:CreateShortcut[${NumProfile}]
    }

    method CreateShortcut(uint numProfile)
    {
        if ${JMB.Build}<6872
            return

        if !${numProfile}
            return

        variable string _filename
        variable string _profileName
        variable string _iconPath
        variable string _target
        variable string _args
        variable string _workingDirectory
        variable string _description

        _profileName:Set["${Settings.Profiles[${numProfile}].Name~}"]
        _filename:Set["%USERPROFILE%\\Desktop\\EverQuest - ${_profileName~}.lnk"]
        _target:Set["${LavishScript.Executable~}"]
        _args:Set["WEQ2022:OnLaunchProfileCommand[${numProfile}]"]
        _workingDirectory:Set["${LavishScript.HomeDirectory~}"]
        _description:Set["EverQuest - ${_profileName~}"]
        _iconPath:Set["${Settings.Profiles[${numProfile}].EQPath~}\\eqgame.exe"]

        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "filename":${_filename.AsJSON~},
            "target":${_target.AsJSON~},
            "args":${_args.AsJSON~},
            "workingDirectory":${_workingDirectory.AsJSON~},
            "description":${_description.AsJSON~},
            "iconPath":${_iconPath.AsJSON~}
        }
        <$$"]

        System:CreateShortcut["${jo.AsJSON~}"]
    }

    ; Used by the Joe Multiboxer right-click menu when the user selects a profile from the Launch menu
    method OnLaunchProfileCommand(uint numProfile)
    {
;        echo OnLaunchProfileCommand[${numProfile}]
        UseProfile:SetReference["Settings.Profiles[${numProfile}]"]
        This:OnLaunchButton
    }

    ; Used by GUI when the user clicks Launch
    method OnLaunchButton()
    {
        variable uint NumProfile=${UseProfile.NumProfile}
        if !${NumProfile}
        {
            ; no profile selected
            echo UseProfile.NumProfile = ${NumProfile}
            return
        }

        variable uint Slot
        ; with this method, clicking launch will first attempt to fill an existing Slot that has not been launched
        ; however, that also means we have to wait between launches or they fill the same Slot.
        Slot:Set[${This.FindEmptySlot}]
        if !${Slot}
            Slot:Set["${JMB.AddSlot.ID}"]

        echo "launching WinEQ 2 profile ${UseProfile.Name} in slot ${Slot}"

        ; install the JMB Character
        This:InstallCharacter[${NumProfile}]
        ; fill in the Slot details by providing the Character ID
        JMB.Slot[${Slot}]:SetCharacter[${This.GetCharacterID[${NumProfile}]}]

        echo character ID = ${JMB.Slot[${Slot}].Character.ID}

        echo launching...
        ; finally, we launch the Slot
        if !${JMB.Slot[${Slot}]:Launch(exists)}
        {
            echo Launch failed?
        }

    }

    ; Used by GUI when the user clicks the button to use defaults
    method OnDefaultsButton()
    {
        ; hide our first run window error box
        LGUI2.Element[weq2022.FirstRun.NotFound]:SetVisibility[Collapsed]

        variable jsonvalue joDefaults
        ; retrieve the handy dandy "weq2022.defaultSettings" template from our LGUI2 package file
        joDefaults:SetValue["${LGUI2.Template["weq2022.defaultSettings"].AsJSON~}"]
        ; and apply that to our Settings to install default settings!
        Settings:FromJSON["joDefaults"]

        ; store the new settings as our own JSON file
        Settings:ExportJSON

        ; hide our "first run" window
        LGUI2.Element[weq2022.FirstRun]:SetVisibility[Hidden]
        ; show our main window
        LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]:BubbleToTop
    }

    ; Used by GUI when the user clicks the button to import settings from WinEQ 2 folder
    method OnImportButton()
    {
        variable filepath fpFolder="${WinEQ2Folder~}"
        ; first make sure we have a file called wineq-eq.ini in the specified WinEQ 2 folder
        if !${fpFolder.FileExists[wineq-eq.ini]}
        {
            ; nope. we can show an error that helps the user identify the problem (if this was not expected, anyway)
            LGUI2.Element[weq2022.FirstRun.NotFound]:SetText["WinEQ 2 not found in ${WEQ2022.WinEQ2Folder~}"]:SetVisibility[Visible]
            return
        }

        ; there is a file there, so if we showed a "not found" message before go ahead and hide it
        LGUI2.Element[weq2022.FirstRun.NotFound]:SetVisibility[Collapsed]

        ; now do the actual importing
        if !${Settings:ImportINI["${WinEQ2Folder~}/wineq-eq.ini"](exists)}
        {
            echo "[WEQ2022] Import failed..."
            return
        }

        This:InstallMenu
        This:InstallEQFolders
        ; store the new settings as our own JSON file
        Settings:ExportJSON

        ; hide our "first run" window
        LGUI2.Element[weq2022.FirstRun]:SetVisibility[Hidden]
        ; show our main window
        LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]:BubbleToTop
    }

    ; Get a reference to a profile, by name
    member:weakref FindProfile(string name)
    {
        variable int i
        for (i:Set[1] ; ${i}<=30 ; i:Inc)
        {
            if ${Settings.Profiles[${i}].Name.Equal["${name~}"]}
            {
 ;               echo "profile ${name} found #${i}"
                return "Settings.Profiles[${i}]"
            }
        }

 ;       echo "profile ${name} not found #${i}"
    }

    ; Sets the currently selected Profile, by name
    method SetProfile(string name)
    {
;        echo SetProfile ${name}
        UseProfile:SetReference["This.FindProfile[\"${name~}\"]"]
    }

    method SelectPreset(uint id)
    {
        SelectedPreset:SetReference["This.Settings.Presets[${id}]"]
    }

    method SetLockGamma(bool newValue)
    {
        if ${newValue}==${Settings.LockGamma}
            return

        Settings.LockGamma:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetLockGamma[${newValue}]"
        Settings:ExportJSON
    }

    method SetLockWindow(bool newValue)
    {
        if ${newValue}==${Settings.LockWindow}
            return

        Settings.LockWindow:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetLockWindow[${newValue}]"
        Settings:ExportJSON
    }

    method SetForceWindowed(bool newValue)
    {
        if ${newValue}==${Settings.ForceWindowed}
            return

        Settings.ForceWindowed:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetForceWindowed[${newValue}]"
        Settings:ExportJSON
    }

    method SetUseEQPlayNice(bool newValue)
    {
        if ${newValue}==${Settings.UseEQPlayNice}
            return

        Settings.UseEQPlayNice:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetUseEQPlayNice[${newValue}]"
        Settings:ExportJSON
    }

    method SetRenderStrobeInterval(float newValue)
    {
        if ${newValue}==${Settings.RenderStrobeInterval}
            return

        Settings.RenderStrobeInterval:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetRenderStrobeInterval[${newValue}]"
        Settings:ExportJSON
    }

    method SetForegroundFPS(uint newValue)
    {
        if ${newValue}==${Settings.ForegroundFPS}
            return

        Settings.ForegroundFPS:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetForegroundFPS[${newValue}]"
        Settings:ExportJSON
    }

    method SetBackgroundFPS(uint newValue)
    {
        if ${newValue}==${Settings.BackgroundFPS}
            return

        Settings.BackgroundFPS:Set[${newValue}]
        relay all -noredirect "WEQ2022Session:SetBackgroundFPS[${newValue}]"
        Settings:ExportJSON
    }

    method Save()
    {
        Settings:ExportJSON
        relay all -noredirect "JMB.Agent[WinEQ 2022]:Stop:Start"
    }

    ; Retrieve a list of Profiles that have names
    member:jsonvalueref Profiles()
    {
        variable jsonvalue ja="[]"

        variable int i
        for (i:Set[1] ; ${i}<=30 ; i:Inc)
        {
            if ${Settings.Profiles[${i}].Name.NotNULLOrEmpty}
            {
                ja:AddByRef["Settings.Profiles[${i}].AsJSON"]
            }
        }

        return ja
    }

    method AddAgentProvider()
    {
        JMB:AddAgentProvider["","${LGUI2.Template[weq2022.devProvider]~}"]        
    }

    method RemoveAgentProvider()
    {
        JMB.AgentProvider[WinEQ-2022-dev]:Remove
    }

    method Restart()
    {
        JMB.AgentProvider[WinEQ-2022-dev].Listing[WinEQ-2022-dev]:Install
        timed 1 "JMB.Agent[WinEQ 2022]:Stop:Reload:Start"
        timed 1 "relay all -noredirect \"JMB.Agent[WinEQ 2022]:Stop:Reload:Start\""
    }

}

variable(global) weq2022 WEQ2022

function main()
{
    while 1
        waitframe
}