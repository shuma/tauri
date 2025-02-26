Var AppStartMenuFolder
Var ReinstallPageCheck

!include MUI2.nsh
!include FileFunc.nsh
!include x64.nsh
!include WordFunc.nsh

!define MANUFACTURER "{{manufacturer}}"
!define PRODUCTNAME "{{product_name}}"
!define VERSION "{{version}}"
!define VERSIONWITHBUILD "{{version_with_build}}"
!define SHORTDESCRIPTION "{{short_description}}"
!define INSTALLMODE "{{install_mode}}"
!define LICENSE "{{license}}"
!define INSTALLERICON "{{installer_icon}}"
!define SIDEBARIMAGE "{{sidebar_image}}"
!define HEADERIMAGE "{{header_image}}"
!define MAINBINARYNAME "{{main_binary_name}}"
!define MAINBINARYSRCPATH "{{main_binary_path}}"
!define BUNDLEID "{{bundle_id}}"
!define OUTFILE "{{out_file}}"
!define ARCH "{{arch}}"
!define PLUGINSPATH "{{additional_plugins_path}}"
!define ALLOWDOWNGRADES "{{allow_downgrades}}"
!define DISPLAYLANGUAGESELECTOR "{{display_language_selector}}"
!define INSTALLWEBVIEW2MODE "{{install_webview2_mode}}"
!define WEBVIEW2INSTALLERARGS "{{webview2_installer_args}}"
!define WEBVIEW2BOOTSTRAPPERPATH "{{webview2_bootstrapper_path}}"
!define WEBVIEW2INSTALLERPATH "{{webview2_installer_path}}"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCTNAME}"
!define MANUPRODUCTKEY "Software\${MANUFACTURER}\${PRODUCTNAME}"

Name "${PRODUCTNAME}"
BrandingText "{{copyright}}"
OutFile "${OUTFILE}"
Unicode true
SetCompressor /SOLID lzma

VIProductVersion "${VERSIONWITHBUILD}"
VIAddVersionKey "ProductName" "${PRODUCTNAME}"
VIAddVersionKey "FileDescription" "${SHORTDESCRIPTION}"
VIAddVersionKey "LegalCopyright" "${COPYRIGHT}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"

!if "${PLUGINSPATH}" != ""
    !addplugindir "${PLUGINSPATH}"
!endif


!if "${INSTALLMODE}" == "perMachine"
  RequestExecutionLevel highest
!endif

!if "${INSTALLMODE}" == "currentUser"
  RequestExecutionLevel user
!endif

!if "${INSTALLMODE}" == "both"
  !define MULTIUSER_MUI
  !define MULTIUSER_INSTALLMODE_INSTDIR "${PRODUCTNAME}"
  !define MULTIUSER_INSTALLMODE_COMMANDLINE
  !if "${ARCH}" == "x64"
    !define MULTIUSER_USE_PROGRAMFILES64
  !else if "${ARCH}" == "arm64"
    !define MULTIUSER_USE_PROGRAMFILES64
  !endif
  !define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_KEY "${UNINSTKEY}"
  !define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME "CurrentUser"
  !define MULTIUSER_INSTALLMODEPAGE_SHOWUSERNAME
  !define MULTIUSER_INSTALLMODE_FUNCTION RestorePreviousInstallLocation
  !define MULTIUSER_EXECUTIONLEVEL Highest
  !include MultiUser.nsh
!endif

!if "${INSTALLERICON}" != ""
  !define MUI_ICON "${INSTALLERICON}"
!endif

!if "${SIDEBARIMAGE}" != ""
  !define MUI_WELCOMEFINISHPAGE_BITMAP "${SIDEBARIMAGE}"
!endif

!if "${HEADERIMAGE}" != ""
  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_BITMAP  "${HEADERIMAGE}"
!endif

; Define registry key to store installer language
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "${MANUPRODUCTKEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"

; Installer pages, must be ordered as they appear
!insertmacro MUI_PAGE_WELCOME
!if "${LICENSE}" != ""
  !insertmacro MUI_PAGE_LICENSE "${LICENSE}"
!endif
!if "${INSTALLMODE}" == "both"
  !insertmacro MULTIUSER_PAGE_INSTALLMODE
!endif

; Custom page to ask user if he wants to reinstall/uninstall
Page custom PageReinstall PageLeaveReinstall
Function PageReinstall
  ; Check if there is an existing installation, if not, abort the reinstall page
  ReadRegStr $R0 SHCTX "${UNINSTKEY}" ""
  ReadRegStr $R1 SHCTX "${UNINSTKEY}" "UninstallString"
  ${IfThen} "$R0$R1" == "" ${|} Abort ${|}

  ; Compare this installar version with the existing installation and modify the messages presented to the user accordingly
  StrCpy $R4 "$(older)"
  ReadRegStr $R0 SHCTX "${UNINSTKEY}" "DisplayVersion"
  ${IfThen} $R0 == "" ${|} StrCpy $R4 "$(unknown)" ${|}

  nsis_tauri_utils::SemverCompare "${VERSION}" $R0
  Pop $R0
  ; Reinstalling the same version
  ${If} $R0 == 0
    StrCpy $R1 "$(alreadyInstalledLong)"
    StrCpy $R2 "$(addOrReinstall)"
    StrCpy $R3 "$(uninstallApp)"
    !insertmacro MUI_HEADER_TEXT "$(alreadyInstalled)" "$(chooseMaintenanceOption)"
    StrCpy $R0 "2"
  ; Upgrading
  ${ElseIf} $R0 == 1
    StrCpy $R1 "$(olderOrUnknownVersionInstalled)"
    StrCpy $R2 "$(uninstallBeforeInstalling)"
    StrCpy $R3 "$(dontUninstall)"
    !insertmacro MUI_HEADER_TEXT "$(alreadyInstalled)" "$(choowHowToInstall)"
    StrCpy $R0 "1"
  ; Downgrading
  ${ElseIf} $R0 == -1
    StrCpy $R1 "$(newerVersionInstalled)"
    StrCpy $R2 "$(uninstallBeforeInstalling)"
    !if "${ALLOWDOWNGRADES}" == "true"
      StrCpy $R3 "$(dontUninstall)"
    !else
      StrCpy $R3 "$(dontUninstallDowngrade)"
    !endif
    !insertmacro MUI_HEADER_TEXT "$(alreadyInstalled)" "$(choowHowToInstall)"
    StrCpy $R0 "1"
  ${Else}
    Abort
  ${EndIf}

  nsDialogs::Create 1018
  Pop $R4
  ${If} $(^RTL) == 1
    nsDialogs::SetRTL $(^RTL)
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 24u $R1
  Pop $R1

  ${NSD_CreateRadioButton} 30u 50u -30u 8u $R2
  Pop $R2
  ${NSD_OnClick} $R2 PageReinstallUpdateSelection

  ${NSD_CreateRadioButton} 30u 70u -30u 8u $R3
  Pop $R3
  ; disable this radio button if downgrades are not allowed
  !if "${ALLOWDOWNGRADES}" == "false"
    EnableWindow $R3 0
  !endif
  ${NSD_OnClick} $R3 PageReinstallUpdateSelection

  ${If} $ReinstallPageCheck != 2
    SendMessage $R2 ${BM_SETCHECK} ${BST_CHECKED} 0
  ${Else}
    SendMessage $R3 ${BM_SETCHECK} ${BST_CHECKED} 0
  ${EndIf}

  ${NSD_SetFocus} $R2

  nsDialogs::Show
FunctionEnd
Function PageReinstallUpdateSelection
  Pop $R1

  ${NSD_GetState} $R2 $R1

  ${If} $R1 == ${BST_CHECKED}
    StrCpy $ReinstallPageCheck 1
  ${Else}
    StrCpy $ReinstallPageCheck 2
  ${EndIf}

FunctionEnd
Function PageLeaveReinstall
  ${NSD_GetState} $R2 $R1

  ; $R0 holds whether we are reinstalling the same version or not
  ; $R0 == "1" -> different versions
  ; $R0 == "2" -> same version
  ;
  ; $R1 holds the radio buttons state. its meaning is dependant on the context
  StrCmp $R0 "1" 0 +2 ; Existing install is not the same version?
    StrCmp $R1 "1" reinst_uninstall reinst_done
  StrCmp $R1 "1" reinst_done ; Same version, skip to add/reinstall components?

  reinst_uninstall:
    ReadRegStr $4 SHCTX "${MANUPRODUCTKEY}" ""
    ReadRegStr $R1 SHCTX "${UNINSTKEY}" "UninstallString"

    HideWindow

    ClearErrors
    ExecWait '$R1 _?=$4' $0

    BringToFront

    ${IfThen} ${Errors} ${|} StrCpy $0 2 ${|} ; ExecWait failed, set fake exit code

    ${If} $0 <> 0
    ${OrIf} ${FileExists} "$INSTDIR\${MAINBINARYNAME}.exe"
      ${If} $0 = 1 ; User aborted uninstaller?
        StrCmp $R0 "2" 0 +2 ; Is the existing install the same version?
          Quit ; ...yes, already installed, we are done
        Abort
      ${EndIf}
      MessageBox MB_ICONEXCLAMATION "$(unableToUninstall)"
      Abort
    ${Else}
      StrCpy $0 $R1 1
      ${IfThen} $0 == '"' ${|} StrCpy $R1 $R1 -1 1 ${|} ; Strip quotes from UninstallString
      Delete $R1
      RMDir $INSTDIR
    ${EndIf}

  reinst_done:
FunctionEnd

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU Application $AppStartMenuFolder
!insertmacro MUI_PAGE_INSTFILES

; Don't auto jump to finish page after installation page,
; because the installation page has useful info that can be used debug any issues with the installer.
!define MUI_FINISHPAGE_NOAUTOCLOSE
; Use show readme button in the finish page to create a desktop shortcut
!define MUI_FINISHPAGE_SHOWREADME
!define MUI_FINISHPAGE_SHOWREADME_TEXT "$(createDesktop)"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION CreateDesktopShortcut
Function CreateDesktopShortcut
  CreateShortcut "$DESKTOP\${MAINBINARYNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
  ApplicationID::Set "$DESKTOP\${MAINBINARYNAME}.lnk" "${BUNDLEID}"
FunctionEnd
; Show run app after installation.
!define MUI_FINISHPAGE_RUN "$INSTDIR\${MAINBINARYNAME}.exe"
!insertmacro MUI_PAGE_FINISH

; Uninstaller Pages
Var DeleteAppDataCheckbox
Var DeleteAppDataCheckboxState
!define /ifndef WS_EX_LAYOUTRTL         0x00400000
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.ConfirmShow
Function un.ConfirmShow
    FindWindow $1 "#32770" "" $HWNDPARENT ; Find inner dialog
    ${If} $(^RTL) == 1
      System::Call 'USER32::CreateWindowEx(i${__NSD_CheckBox_EXSTYLE}|${WS_EX_LAYOUTRTL},t"${__NSD_CheckBox_CLASS}",t "$(deleteAppData)",i${__NSD_CheckBox_STYLE},i 50,i 100,i 400, i 25,i$1,i0,i0,i0)i.s'
    ${Else}
      System::Call 'USER32::CreateWindowEx(i${__NSD_CheckBox_EXSTYLE},t"${__NSD_CheckBox_CLASS}",t "$(deleteAppData)",i${__NSD_CheckBox_STYLE},i 0,i 100,i 400, i 25,i$1,i0,i0,i0)i.s'
    ${EndIf}
    Pop $DeleteAppDataCheckbox
    SendMessage $HWNDPARENT ${WM_GETFONT} 0 0 $1
    SendMessage $DeleteAppDataCheckbox ${WM_SETFONT} $1 1
FunctionEnd
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE un.ConfirmLeave
Function un.ConfirmLeave
    SendMessage $DeleteAppDataCheckbox ${BM_GETCHECK} 0 0 $DeleteAppDataCheckboxState
FunctionEnd
!insertmacro MUI_UNPAGE_CONFIRM

!insertmacro MUI_UNPAGE_INSTFILES

;Languages
{{#each languages}}
!insertmacro MUI_LANGUAGE "{{this}}"
{{/each}}
!insertmacro MUI_RESERVEFILE_LANGDLL
{{#each language_files}}
  !include "{{this}}"
{{/each}}

Function .onInit
  !if "${DISPLAYLANGUAGESELECTOR}" == "true"
    !insertmacro MUI_LANGDLL_DISPLAY
  !endif

  !if "${INSTALLMODE}" == "currentUser"
    SetShellVarContext current
  !else if "${INSTALLMODE}" == "perMachine"
    SetShellVarContext all
  !endif

  ${If} $INSTDIR == ""
    !if "${INSTALLMODE}" == "perMachine"
      ; Set default install location
      ${If} ${RunningX64}
        !if "${ARCH}" == "x64"
          StrCpy $INSTDIR "$PROGRAMFILES64\${PRODUCTNAME}"
        !else if "${ARCH}" == "arm64"
          StrCpy $INSTDIR "$PROGRAMFILES64\${PRODUCTNAME}"
        !else
          StrCpy $INSTDIR "$PROGRAMFILES\${PRODUCTNAME}"
        !endif
      ${Else}
        StrCpy $INSTDIR "$PROGRAMFILES\${PRODUCTNAME}"
      ${EndIf}
    !else if "${INSTALLMODE}" == "currentUser"
      StrCpy $INSTDIR "$LOCALAPPDATA\${PRODUCTNAME}"
    !endif

    Call RestorePreviousInstallLocation
  ${EndIf}


  !if "${INSTALLMODE}" == "both"
    !insertmacro MULTIUSER_INIT
  !endif
FunctionEnd

Section EarlyChecks
  ; Abort silent installer if downgrades is disabled
  !if "${ALLOWDOWNGRADES}" == "false"
  IfSilent 0 done
    System::Call 'kernel32::AttachConsole(i -1)i.r0'
    ${If} $0 != 0
      System::Call 'kernel32::GetStdHandle(i -11)i.r0'
      System::call 'kernel32::SetConsoleTextAttribute(i r0, i 0x0004)' ; set red color
      FileWrite $0 "$(silentDowngrades)"
    ${EndIf}
    Abort
  done:
  !endif
SectionEnd

Section Webview2
  ; Check if Webview2 is already installed and skip this section
  ${If} ${RunningX64}
    ReadRegStr $4 HKLM "SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
  ${Else}
    ReadRegStr $4 HKLM "SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
  ${EndIf}
  ReadRegStr $5 HKCU "SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"

  StrCmp $4 "" 0 done
  StrCmp $5 "" 0 done

  ;--------------------------------
  ; Webview2 install modes

  !if "${INSTALLWEBVIEW2MODE}" == "downloadBootstrapper"
    Delete "$TEMP\MicrosoftEdgeWebview2Setup.exe"
    DetailPrint "$(webview2Downloading)"
    nsis_tauri_utils::download "https://go.microsoft.com/fwlink/p/?LinkId=2124703" "$TEMP\MicrosoftEdgeWebview2Setup.exe"
    Pop $0
    ${If} $0 == 0
      DetailPrint "$(webview2DownloadSuccess)"
    ${Else}
      DetailPrint "$(webview2DownloadError)"
      Abort "$(webview2AbortError)"
    ${EndIf}
    StrCpy $6 "$TEMP\MicrosoftEdgeWebview2Setup.exe"
    Goto install_webview2
  !endif

  !if "${INSTALLWEBVIEW2MODE}" == "embedBootstrapper"
    CreateDirectory "$INSTDIR\redist"
    File "/oname=$INSTDIR\redist\MicrosoftEdgeWebview2Setup.exe" "${WEBVIEW2BOOTSTRAPPERPATH}"
    DetailPrint "$(installingWebview2)"
    StrCpy $6 "$INSTDIR\redist\MicrosoftEdgeWebview2Setup.exe"
    Goto install_webview2
  !endif

  !if "${INSTALLWEBVIEW2MODE}" == "offlineInstaller"
    CreateDirectory "$INSTDIR\redist"
    File "/oname=$INSTDIR\redist\MicrosoftEdgeWebView2RuntimeInstaller.exe" "${WEBVIEW2INSTALLERPATH}"
    DetailPrint "$(installingWebview2)"
    StrCpy $6 "$INSTDIR\redist\MicrosoftEdgeWebView2RuntimeInstaller.exe"
    Goto install_webview2
  !endif

  Goto done

  install_webview2:
    DetailPrint "$(installingWebview2)"
    ; $6 holds the path to the webview2 installer
    ExecWait "$6 ${WEBVIEW2INSTALLERARGS} /install" $1
    ${If} $1 == 0
      DetailPrint "$(webview2InstallSuccess)"
    ${Else}
      DetailPrint "$(webview2InstallError)"
      Abort "$(webview2AbortError)"
    ${EndIf}

  done:
SectionEnd

!macro CheckIfAppIsRunning
  nsis_tauri_utils::FindProcess "${MAINBINARYNAME}.exe"
  Pop $R0
  ${If} $R0 = 0
    IfSilent silent ui
    silent:
      System::Call 'kernel32::AttachConsole(i -1)i.r0'
      ${If} $0 != 0
        System::Call 'kernel32::GetStdHandle(i -11)i.r0'
        System::call 'kernel32::SetConsoleTextAttribute(i r0, i 0x0004)' ; set red color
        FileWrite $0 "$(appRunning)$\n"
      ${EndIf}
      Abort
    ui:
      MessageBox MB_OKCANCEL "$(appRunningOkKill)" IDOK ok IDCANCEL cancel
      ok:
        nsis_tauri_utils::KillProcess "${MAINBINARYNAME}.exe"
        Pop $R0
        Sleep 500
        ${If} $R0 = 0
          Goto done
        ${Else}
          Abort "$(failedToKillApp)"
        ${EndIf}
      cancel:
        Abort "$(appRunning)"
  ${EndIf}
  done:
!macroend

Section Install
  SetOutPath $INSTDIR

  !insertmacro CheckIfAppIsRunning

  ; Copy main executable
  File "${MAINBINARYSRCPATH}"

  ; Copy resources
  {{#each resources}}
    CreateDirectory "$INSTDIR\\{{this.[0]}}"
    File /a "/oname={{this.[1]}}" "{{@key}}"
  {{/each}}

  ; Copy external binaries
  {{#each binaries}}
    File /a "/oname={{this}}" "{{@key}}"
  {{/each}}

  ; Create uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Save $INSTDIR in registry for future installations
  WriteRegStr SHCTX "${MANUPRODUCTKEY}" "" $INSTDIR

  !if "${INSTALLMODE}" == "both"
    ; Save install mode to be selected by default for the next installation such as updating
    ; or when uninstalling
    WriteRegStr SHCTX "${UNINSTKEY}" $MultiUser.InstallMode 1
  !endif

  ; Registry information for add/remove programs
  WriteRegStr SHCTX "${UNINSTKEY}" "DisplayName" "${PRODUCTNAME}"
  WriteRegStr SHCTX "${UNINSTKEY}" "DisplayIcon" "$\"$INSTDIR\${MAINBINARYNAME}.exe$\""
  WriteRegStr SHCTX "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr SHCTX "${UNINSTKEY}" "Publisher" "${MANUFACTURER}"
  WriteRegStr SHCTX "${UNINSTKEY}" "InstallLocation" "$\"$INSTDIR$\""
  WriteRegStr SHCTX "${UNINSTKEY}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegDWORD SHCTX "${UNINSTKEY}" "NoModify" "1"
  WriteRegDWORD SHCTX "${UNINSTKEY}" "NoRepair" "1"
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD SHCTX "${UNINSTKEY}" "EstimatedSize" "$0"

  ; Create start menu shortcut
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$SMPROGRAMS\$AppStartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$AppStartMenuFolder\${MAINBINARYNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
    ApplicationID::Set "$SMPROGRAMS\$AppStartMenuFolder\${MAINBINARYNAME}.lnk" "${BUNDLEID}"
  !insertmacro MUI_STARTMENU_WRITE_END

SectionEnd

Var Restart
Function .onInstSuccess
  ; Check for `/R` flag only in silent installer because
  ; gui installer has a toggle for the user to restart the app
  IfSilent 0 done
    ${GetOptions} $CMDLINE "/R" $Restart
    IfErrors done 0 ; if errors were found then `/R` wasn't passed, so we skip restarting
      Exec '"$INSTDIR\${MAINBINARYNAME}.exe"'
  done:
FunctionEnd

Function un.onInit
  !if "${INSTALLMODE}" == "both"
    !insertmacro MULTIUSER_UNINIT
  !endif

  !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

Section Uninstall
  !insertmacro CheckIfAppIsRunning

  ; Delete the app directory and its content from disk
  ; Copy main executable
  Delete "$INSTDIR\${MAINBINARYNAME}.exe"

  ; Delete resources
  {{#each resources}}
    Delete "$INSTDIR\\{{this.[1]}}"
    RMDir "$INSTDIR\\{{this.[0]}}"
  {{/each}}

  ; Delete external binaries
  {{#each binaries}}
    Delete "$INSTDIR\\{{this}}"
  {{/each}}

  ; Delete uninstaller
  Delete "$INSTDIR\uninstall.exe"

  RMDir "$INSTDIR"

  ; Remove start menu shortcut
  !insertmacro MUI_STARTMENU_GETFOLDER Application $AppStartMenuFolder
  Delete "$SMPROGRAMS\$AppStartMenuFolder\${MAINBINARYNAME}.lnk"
  RMDir "$SMPROGRAMS\$AppStartMenuFolder"

  ; Remove desktop shortcuts
  Delete "$DESKTOP\${MAINBINARYNAME}.lnk"

  ; Delete app data
  ${If} $DeleteAppDataCheckboxState == 1
    RmDir /r "$APPDATA\${BUNDLEID}"
    RmDir /r "$LOCALAPPDATA\${BUNDLEID}"
  ${EndIf}

  ; Remove registry information for add/remove programs
  !if "${INSTALLMODE}" == "both"
    DeleteRegKey SHCTX "${UNINSTKEY}"
  !else if "${INSTALLMODE}" == "perMachine"
    DeleteRegKey HKLM "${UNINSTKEY}"
  !else
    DeleteRegKey HKCU "${UNINSTKEY}"
  !endif

  DeleteRegValue HKCU "${MANUPRODUCTKEY}" "Installer Language"
SectionEnd

Function RestorePreviousInstallLocation
  ReadRegStr $4 SHCTX "${MANUPRODUCTKEY}" ""
  StrCmp $4 "" +2 0
    StrCpy $INSTDIR $4
FunctionEnd
