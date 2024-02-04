## How to use

### Dependencies
Required packages
```wine wine-mono wine_gecko winetricks p7zip curl cabextract lib32-gnutls```

Optional
```samba```

### Installation
Execute
```
./fusion_installer.sh
```
Script is going to create dir tree (path can be easily changed)
```
/home/lukasz/.fusion360/
├── cache
│   ├── AdditiveAssistant.bundle-win64.msi
│   ├── AirfoilTools_win64.msi
│   ├── Fusion360installer.exe
│   ├── HelicalGear_win64.msi
│   ├── OctoPrint_for_Fusion360-win64.msi
│   ├── ParameterIO_win64.msi
│   └── winetricks
└── wineprefixes
    ├── box-run.sh
[...]
```

## Authorizatoin with fusion SSO
1. After Installation run .fusion/wineprefixes/box-run
2. Click in sing-in banner
3. Default browser should open
4. Login, after redirection clik with right mouse button to retry label which contains ```adskidmgr:/login?code=```
5. Copy content to .fusion360/cache/login.txt
6. Run script with ```auth``` parameter
7. Fusion should login.

### Update
move current directory to .fusion_backup and jump to Installation step

## Know issues
### Cab installer manual intervention
https://github.com/Winetricks/winetricks/pull/2025

Script is going to wait for user input.

*ArchLinux require patching.

### Hard drive access issue
Wine or kernel issue.
Since kernel 6.1 mmc device is being reported as sda and Wine interprets it as partition.
```
d:: -> /dev/sda
```

## Why this project started? 
Every one needs fast, easy to use and maintain solution which just works.

## Performance
For best performance (25.02.2023) set fusion to run with opengl and do not apply any external solutions

![sample-out](https://user-images.githubusercontent.com/219793/221354633-722b0a1f-4efc-42fb-b004-5e7a3cfdeb95.png)

## Tested on
ArchLinux

### Special thanks to
Steve Zabka from https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux 
