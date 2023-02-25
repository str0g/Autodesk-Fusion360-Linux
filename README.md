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
d:: -> /dev/sda wine created dvice?
```

## Why this project started? 
Every one needs fast, easy to use and maintain solution which just works.

## Performance
For best performance (25.02.2023) set fusion to run with opengl and do not apply any external solutions

![sample-out](https://https://github.com/str0g/Autodesk-Fusion360-Linux/doc/graphic_driver.png)

## Tested on
ArchLinux

### Special thanks to
Steve Zabka from https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux 