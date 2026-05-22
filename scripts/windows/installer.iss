; Inno Setup script for richtext (Flutter Windows desktop app).
; Compile with ISCC.exe (Inno Setup 6+). Invoked by build_installer.bat.

#define MyAppName      "richtext"
#define MyAppVersion   "1.0.0"
#define MyAppPublisher "local.richtext"
#define MyAppExeName   "richtext.exe"
#define BuildDir       "..\..\build\windows\x64\runner\Release"
#define OutDir         "..\..\build\installer"
#define IconFile       "..\..\windows\runner\resources\app_icon.ico"

[Setup]
; A fresh GUID identifies this app to Windows. Do NOT reuse across products.
AppId={{8A7F2E1C-9D4B-4E3A-B6F1-7E2C5A1B0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutDir}
OutputBaseFilename=richtext-setup-{#MyAppVersion}
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean";  MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter publishes .exe + .dll + data\ folder under build\windows\x64\runner\Release.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";              Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
