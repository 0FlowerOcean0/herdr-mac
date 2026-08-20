#define MyAppName "Herdr Native Client"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0-preview.2"
#endif
#ifndef PublishDirectory
  #define PublishDirectory "..\..\artifacts\Herdr-for-Windows"
#endif
#ifndef InstallerOutputDirectory
  #define InstallerOutputDirectory "..\..\artifacts"
#endif

[Setup]
AppId={{C8C3E14C-8210-4257-8F74-B067BEE661DE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=0FlowerOcean0
AppPublisherURL=https://github.com/0FlowerOcean0/herdr-mac
AppSupportURL=https://github.com/0FlowerOcean0/herdr-mac/issues
AppUpdatesURL=https://github.com/0FlowerOcean0/herdr-mac/releases
DefaultDirName={localappdata}\Programs\Herdr Native Client
DefaultGroupName=Herdr Native Client
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir={#InstallerOutputDirectory}
OutputBaseFilename=Herdr-for-Windows-{#MyAppVersion}-x64-Setup
SetupIconFile=..\Herdr.Windows\Assets\HerdrAppIcon.ico
UninstallDisplayIcon={app}\Herdr.Windows.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#PublishDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Herdr"; Filename: "{app}\Herdr.Windows.exe"
Name: "{autodesktop}\Herdr"; Filename: "{app}\Herdr.Windows.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\Herdr.Windows.exe"; Description: "{cm:LaunchProgram,Herdr}"; Flags: nowait postinstall skipifsilent
