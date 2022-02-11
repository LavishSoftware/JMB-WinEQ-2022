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
        
        if ${JMB.Build}<6861
        {
            echo "WinEQ 2022 requires JMB build 6861 or later"
            return
        }
        
        ; Load our GUI
        LGUI2:LoadPackageFile[WEQ2022.Uplink.lgui2Package.json]

        ; If our JSON settings file does not exist, we should offer to provide defaults or allow the user to import from WinEQ 2
        if !${Settings.SettingsFileExists}
        {
            ; first run
            LGUI2.Element[weq2022.FirstRun]:SetVisibility[Visible]

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
            LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]            
        }

        This:SetProfile["WinEQ 2.0 Default Profile"]
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
        ; with this method, clicking launch will always add a new Slot, even if some are empty.
        ; we can add better management to this agent to re-use empty Slots
        ; the Basic Session Manager agent can be used to manage Slots, including re-launching a given Slot
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
        LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]
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
        This:InstallEQFolders
        ; store the new settings as our own JSON file
        Settings:ExportJSON

        ; hide our "first run" window
        LGUI2.Element[weq2022.FirstRun]:SetVisibility[Hidden]
        ; show our main window
        LGUI2.Element[weq2022.MainWindow]:SetVisibility[Visible]
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