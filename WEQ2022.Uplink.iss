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

    ; Object constructor
    method Initialize()
    {
        variable filepath fpFolder="${WinEQ2Folder~}"
        
        if ${JMB.Build}<6863
        {
            echo "WinEQ 2022 requires JMB build 6863 or later"
            return
        }
        
        ; Load our GUI
        LGUI2:LoadPackageFile[WEQ2022.Uplink.lgui2Package.json]
        if ${JMB.Build}<6872
        {
            LGUI2.Element[weq2022.createShortcutButton]:SetVisibility[Collapsed]
        }

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
        This:InstallMenu
    }

    ; Object destructor
    method Shutdown()
    {
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
        ; name of the JMB "Game"
        variable string gameName="${Settings.Profiles[${NumProfile}].UseGame~}"
        variable string UseGameProfile
        ; The "Game Profile" used for JMB is always "____ Default Profile"
        UseGameProfile:Set["${gameName~} Default Profile"]

        ; the Character ID to add
        variable uint CharacterID=${This.GetCharacterID[${NumProfile}]}

        ; the Character Name will be the name of the profile 
        variable string CharacterName="${Settings.Profiles[${NumProfile}].Name~}"

        ; add custom eqclient.ini file if specified
        ; note that the default value from WinEQ 2 is ".\eqclient.ini" and that slash should be converted to a / to make things easier
        variable string EQClientINI="${Settings.Profiles[${NumProfile}].EQClientINI.Replace["\\","/"]~}"
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
            "game":${gameName.AsJSON~},
            "gameProfile":${UseGameProfile.AsJSON~},
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

    ; Install any EQ1 folders used by Profiles to Joe Multiboxer as "Games", and insert the name used back in the Profile
    method InstallEQFolders()
    {
        variable filepath fpFolder
        variable int i

        variable int NumFolder=1
        variable string Suffix
        for (i:Set[1] ; ${i}<=30 ; i:Inc)
        {
            if !${Settings.Profiles[${i}].Name.NotNULLOrEmpty} || !${Settings.Profiles[${i}].EQPath.NotNULLOrEmpty} || !${Settings.Profiles[${i}].EQPath.PathExists}
                continue

;            echo "Adding EQ Folder ${Settings.Profiles[${i}].EQPath~}"
            JMBUplink:AddGame[EverQuest Launcher${Suffix},"${Settings.Profiles[${i}].EQPath~}","LaunchPad.exe"]
            JMBUplink:AddGame[EverQuest Client${Suffix},"${Settings.Profiles[${i}].EQPath~}","eqgame.exe","patchme"]

            if ${Settings.Profiles[${i}].Patch}
            {
                Settings.Profiles[${i}].UseGame:Set["EverQuest Launcher${Suffix}"]
            }
            else
            {
                Settings.Profiles[${i}].UseGame:Set["EverQuest Client${Suffix}"]
            }

            NumFolder:Inc
            Suffix:Set[" ${NumFolder}"]
        }
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

        This:InstallEQFolders
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

    ; Generate a listbox item view of a Profile
    method GenerateItemView_Profile()
	{
       ; echo GenerateItemView_Profile ${Context(type)} ${Context.Args}

		; build an itemview lgui2element json
		variable jsonvalue joListBoxItem
        ; Here we use our "weq2022.profileView" template defined in our LGUI2 package file
		joListBoxItem:SetValue["${LGUI2.Template["weq2022.profileView"].AsJSON~}"]
        		
        ; set the view!
		Context:SetView["${joListBoxItem.AsJSON~}"]
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

    ; Retrieve a list of Profiles that have names
    member:jsonvalueref Profiles()
    {
        variable jsonvalue ja="[]"

        variable int i
        for (i:Set[1] ; ${i}<=30 ; i:Inc)
        {
            if ${Settings.Profiles[${i}].Name.NotNULLOrEmpty}
            {
                ja:Add["${Settings.Profiles[${i}].AsJSON~}"]
            }
        }

        return ja
    }

}

variable(global) weq2022 WEQ2022

function main()
{
    while 1
        waitframe
}