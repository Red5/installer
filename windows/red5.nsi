# 
# Red5 NSIS script for java7 builds
# Author: Paul Gregoire
# Date: 09/29/2008
# Updated: 09/01/2016
#

Name Red5

; Request application privileges for Windows Vista and Windows 7
RequestExecutionLevel admin

# Defines
!define REGKEY "SOFTWARE\$(^Name)"
#!define VERSION 1.0.2  # should be specified "-DVERSION=x.y.z" as a command line parameter
!define COMPANY "Red5 Server"
!define DESCRIPTION "Red5 is an Open Source Media Server written in Java"
!define URL https://github.com/Red5
!define BuildRoot ".\work\red5-server"
!define ImageRoot "..\images"
!define CommonsDaemonVersion "1.4.0"

# Additional Includes and Plugins
!addincludedir .\NSIS_Includes
!addplugindir .\NSIS_Plugins

# MUI defines
!define MUI_ICON ${ImageRoot}\red5.ico
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP ${ImageRoot}\red5_header.bmp
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_STARTMENUPAGE_REGISTRY_ROOT HKLM
!define MUI_STARTMENUPAGE_REGISTRY_KEY ${REGKEY}
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME StartMenuGroup
!define MUI_STARTMENUPAGE_DEFAULTFOLDER Red5
;;!define MUI_UNICON ".\images\red5_uninstall.ico"

# Included files
!include Sections.nsh
!include MUI.nsh
!include AdvReplaceInFile.nsh
!include "defines.nsh"

# Reserved Files
ReserveFile "${NSISDIR}/Plugins/amd64-unicode/AdvSplash.dll"

# Variables
Var StartMenuGroup
Var /GLOBAL HTTP_PORT 
Var /GLOBAL IP_ADDRESS

# Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE ..\Red5LicenseInfo.txt
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuGroup
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

# Installer languages
!insertmacro MUI_LANGUAGE English

# Installer attributes
OutFile setup-Red5-${VERSION}.exe
InstallDir $PROGRAMFILES\Red5
CRCCheck on
XPStyle on
ShowInstDetails show
VIProductVersion ${VERSION}.0
VIAddVersionKey ProductName $(^Name)
VIAddVersionKey ProductVersion "${VERSION}"
VIAddVersionKey CompanyName "${COMPANY}"
VIAddVersionKey CompanyWebsite "${URL}"
VIAddVersionKey FileVersion "${VERSION}"
VIAddVersionKey FileDescription "${DESCRIPTION}"
VIAddVersionKey LegalCopyright ""
InstallDirRegKey HKLM "${REGKEY}" Path
ShowUninstDetails show

# Installer sections
Section -Main SEC0000
    SetOutPath $INSTDIR
    SetOverwrite on
    ; copy daemon binaries
    File /r /x .svn /x .git /x *.txt .\work\commons-daemon-${CommonsDaemonVersion}-bin-windows\*
    ; copy the java files
    File /r /x war /x *.sh /x Makefile /x *.gz /x *.zip ${BuildRoot}\*
    ; cd and copy the docs
    SetOutPath $INSTDIR\doc
	File /r /x .svn ${BuildRoot}\apidocs
    ; create the log dir
    SetOutPath $INSTDIR\log
    ; create the temp dir
    SetOutPath $INSTDIR\temp
    WriteRegStr HKLM "${REGKEY}\Components" Main 1
SectionEnd

Section -post SEC0001
    WriteRegStr HKLM "${REGKEY}" Path $INSTDIR
    SetOutPath $INSTDIR

    !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    SetOutPath $SMPROGRAMS\$StartMenuGroup
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\Start $(^Name).lnk" $INSTDIR\red5.bat
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\Stop $(^Name).lnk" $INSTDIR\red5-shutdown.bat
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\$(^Name) on the Web.lnk" "https://github.com/Red5/"
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\API documents.lnk" $INSTDIR\doc\apidocs\index.html
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\Bugtracker.lnk" "https://github.com/Red5/red5-server/issues"
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\Wiki.lnk" "https://github.com/Red5/red5-server/wiki"
    CreateShortcut "$SMPROGRAMS\$StartMenuGroup\Uninstall $(^Name).lnk" $INSTDIR\uninstall.exe
    !insertmacro MUI_STARTMENU_WRITE_END

    WriteUninstaller $INSTDIR\uninstall.exe

    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayName "$(^Name)"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayVersion "${VERSION}"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" Publisher "${COMPANY}"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" URLInfoAbout "${URL}"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayIcon $INSTDIR\uninstall.exe
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" UninstallString $INSTDIR\uninstall.exe
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" NoModify 1
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" NoRepair 1

	# set directory accesses
	AccessControl::GrantOnFile "$INSTDIR" "(BU)" "FullAccess"
	
	#Dialogs::InputBox [dialog_title] [caption_inner_text] [caption_button1] [caption_button2] [apply_password] [output_var] 
	Dialogs::InputBox "IP Address" "Enter an IP address for your server:" "Ok" "Cancel" 0 ${VAR_R2} 

	${If} $R2 == ""
	  StrCpy $IP_ADDRESS "0.0.0.0"
    ${Else}
	  StrCpy $IP_ADDRESS $R2
	${EndIf}
	
	Dialogs::InputBox "HTTP Port" "Enter a port number to use for HTTP requests:" "Ok" "Cancel" 0 ${VAR_R3}
	  
	${If} $R3 == ""
	  StrCpy $HTTP_PORT "5080"
    ${Else}
	  StrCpy $HTTP_PORT $R3
	${EndIf}
	  
	# Replace http and rtmp address
	Push "http.host=0.0.0.0"
	Push "http.host=$IP_ADDRESS"
	Push all
	Push all
	Push "$INSTDIR\conf\red5.properties"
	Call AdvReplaceInFile
	
	Push "rtmp.host=0.0.0.0"
	Push "rtmp.host=$IP_ADDRESS"
	Push all
	Push all
	Push "$INSTDIR\conf\red5.properties"
	Call AdvReplaceInFile

	# Replace http port
	Push "http.port=5080"
	Push "http.port=$HTTP_PORT"
	Push all
	Push all
	Push "$INSTDIR\conf\red5.properties"
	Call AdvReplaceInFile
	
    # Add the service
    ExecWait '"$INSTDIR\install-service.bat"'
    ; send them to google code site
    ExecShell "open" "https://github.com/Red5/"
SectionEnd

# Macro for selecting uninstaller sections
!macro SELECT_UNSECTION SECTION_NAME UNSECTION_ID
    Push $R0
    ReadRegStr $R0 HKLM "${REGKEY}\Components" "${SECTION_NAME}"
    StrCmp $R0 1 0 next${UNSECTION_ID}
    !insertmacro SelectSection "${UNSECTION_ID}"
    GoTo done${UNSECTION_ID}
next${UNSECTION_ID}:
    !insertmacro UnselectSection "${UNSECTION_ID}"
done${UNSECTION_ID}:
    Pop $R0
!macroend

# Uninstaller sections
Section /o -un.Main UNSEC0000
    # remove the service
    ExecWait '"$INSTDIR\uninstall-service.bat"'
    RmDir /r /REBOOTOK $INSTDIR
    DeleteRegValue HKLM "${REGKEY}\Components" Main
SectionEnd

Section -un.post UNSEC0001
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)"
    Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\Start $(^Name).lnk"
    Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\Stop $(^Name).lnk"
    Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\$(^Name) on the Web.lnk" 
    Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\Bugtracker.lnk"
    Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\API documents.lnk"
    Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\Uninstall $(^Name).lnk"
    Delete /REBOOTOK $INSTDIR\uninstall.exe
    DeleteRegValue HKLM "${REGKEY}" StartMenuGroup
    DeleteRegValue HKLM "${REGKEY}" Path
    DeleteRegKey /IfEmpty HKLM "${REGKEY}\Components"
    DeleteRegKey /IfEmpty HKLM "${REGKEY}"
    RmDir /REBOOTOK $SMPROGRAMS\$StartMenuGroup
    RmDir /REBOOTOK $INSTDIR
    Push $R0
    StrCpy $R0 $StartMenuGroup 1
    StrCmp $R0 ">" no_smgroup
no_smgroup:
    Pop $R0
SectionEnd

# Installer functions
Function .onInit
    InitPluginsDir
    Push $R1
    File /oname=$PLUGINSDIR\spltmp.bmp ${ImageRoot}\red5splash.bmp
    advsplash::show 1000 600 400 -1 $PLUGINSDIR\spltmp
    Pop $R1
    Pop $R1
FunctionEnd

# Uninstaller functions
Function un.onInit
    SetAutoClose true
    ReadRegStr $INSTDIR HKLM "${REGKEY}" Path
    !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuGroup
    !insertmacro SELECT_UNSECTION Main ${UNSEC0000}
FunctionEnd

