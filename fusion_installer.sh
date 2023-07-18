#! /bin/bash
# Author @Łukasz Buśko
# Licence: non

DEFAULT_WORK_DIR="$HOME/.fusion360"
DEFAULT_WORK_DIR_CACHE="${DEFAULT_WORK_DIR}/cache"
DEFAULT_WORK_DIR_WINE_PREFIX="${DEFAULT_WORK_DIR}/wineprefixes"
DEFAULT_FUSION_INSTALLER_NAME=Fusion360installer.exe
DEFAULT_GFX=dxvk
DEFAULT_BOX="$DEFAULT_WORK_DIR_WINE_PREFIX/box-run.sh"

function init() {
    mkdir -vp "${DEFAULT_WORK_DIR_CACHE}"
    if [ ! -d "${DEFAULT_WORK_DIR_WINE_PREFIX}" ]; then
        mkdir -vp "${DEFAULT_WORK_DIR_WINE_PREFIX}"
        cat >> "$DEFAULT_BOX" << EOF
#!/bin/bash
EOF
        chmod +x "$DEFAULT_BOX"
    fi
}

function download_winetricks() {
    local wtricks="$DEFAULT_WORK_DIR_CACHE/winetricks"
    if [ ! -f "$wtricks" ]; then
        curl https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks --output "$wtricks"
        chmod +x "$wtricks"
    fi
}

function backup_fusion_installer() {
    local fusion_installer="$DEFAULT_WORK_DIR_CACHE/$DEFAULT_FUSION_INSTALLER_NAME"
    mv $fusion_installer "$fusion_installer_$(stat -c %w $fusion_installer)"
}

function download_fusion_installer() {
    local fusion_installer="$DEFAULT_WORK_DIR_CACHE/$DEFAULT_FUSION_INSTALLER_NAME"
    if [ ! -f "$fusion_installer" ]; then
        curl https://dl.appstreaming.autodesk.com/production/installers/Fusion%20360%20Admin%20Install.exe --output $fusion_installer;
        cp "$fusion_installer" "$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c/users/$USER/Downloads/"
    fi
}

function force_windows_version() {
  WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine winecfg -v win10
}

function setup_winetricks() {
    if [ ! -d "$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c" ]; then
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q sandbox &&
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q atmlib gdiplus corefonts cjkfonts dotnet452 msxml4 msxml6 vcrun2017 fontsmooth=rgb winhttp win10 &&
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q $DEFAULT_GFX &&
        force_windows_version
    fi
}

function install_fusion() {
  local fexec="$(find "$DEFAULT_WORK_DIR_WINE_PREFIX" -name Fusion360.exe)"
  if [ ! -f "$fexec" ]; then
    WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" timeout -k 10m 9m wine "$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c/users/$USER/Downloads/$DEFAULT_FUSION_INSTALLER_NAME"
    local fexec="$(find "$DEFAULT_WORK_DIR_WINE_PREFIX" -name Fusion360.exe)"
    echo "WINEPREFIX=\"$DEFAULT_WORK_DIR_WINE_PREFIX\" FUSION_IDSDK=false wine \"$fexec\"" >> "$DEFAULT_BOX"
  fi
}

function install_fusion_addons() {
    local addons="AdditiveAssistant.bundle-win64.msi ParameterIO_win64.msi OctoPrint_for_Fusion360-win64.msi HelicalGear_win64.msi AirfoilTools_win64.msi"

    for addon in $addons
    do
        local tmp="$DEFAULT_WORK_DIR_CACHE/$addon"
        local dl="$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c/users/$USER/Downloads/$addon"

        if [ ! -f "$tmp" ]; then
            curl https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/extensions/$obj --output "$tmp"
        fi
        cp "$tmp" "$dl"
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine msiexec /i "$dl"
    done
}

function install_action() {
    init
    download_winetricks
    setup_winetricks
    download_fusion_installer
    install_fusion
    install_fusion_addons
    force_windows_version
}

if [ $# -lt 1 ]; then
  install_action
fi

case $1 in
  install)
    install_action
    ;;
  update)
    backup_fusion_installer
    download_fusion_installer
    install_fusion
    force_windows_version
    ;;
esac
