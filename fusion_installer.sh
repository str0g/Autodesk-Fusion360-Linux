#! /bin/bash
# Author @Łukasz Buśko
# Licence: non

DEFAULT_WORK_DIR="$HOME/.fusion360"
DEFAULT_WORK_DIR_CACHE="${DEFAULT_WORK_DIR}/cache"
DEFAULT_WORK_DIR_WINE_PREFIX="${DEFAULT_WORK_DIR}/wineprefixes"
DEFAULT_FUSION_INSTALLER_NAME=Fusioninstaller.exe
DEFAULT_WEBVIEW_INSTALLER_NAME=MicrosoftEdgeWebView2RuntimeInstallerX64.exe
DOWNLOADS="$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c/users/$USER/Downloads"
URL_WINETRICKS=https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
URL_WEBVIEW2=https://github.com/aedancullen/webview2-evergreen-standalone-installer-archive/releases/download/109.0.1518.78/MicrosoftEdgeWebView2RuntimeInstallerX64.exe
URL_FUSION=https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe
# GFX options
# galliumnine - dx9
# dvxk dx9/10/11 (vulkan)
# vkd3d - dx12 9 (vulkan)
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
        curl $URL_WINETRICKS --output "$wtricks"
        chmod +x "$wtricks"
    fi
}

function backup_fusion_installer() {
    local fusion_installer="$DEFAULT_WORK_DIR_CACHE/$DEFAULT_FUSION_INSTALLER_NAME"
    mv $fusion_installer "$fusion_installer_$(stat -c %w $fusion_installer)"
}

function download() {
  local url=$1
  local file_path="$DEFAULT_WORK_DIR_CACHE/$2"
  if [ ! -f "$file_path" ]; then
    curl -L $1 --output $file_path;
  fi
  if [ ! -f "$DOWNLOADS/$2" ]; then
    cp "$file_path" "$DOWNLOADS"
  fi
}

function download_webview2_installer() {
  download $URL_WEBVIEW2 $DEFAULT_WEBVIEW_INSTALLER_NAME
}

function download_fusion_installer() {
  download $URL_FUSION $DEFAULT_FUSION_INSTALLER_NAME
}

function force_windows_version() {
  WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine winecfg -v win11
}

function setup_winetricks() {
    if [ ! -d "$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c" ]; then
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q sandbox &&
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q atmlib gdiplus corefonts cjkfonts dotnet452 msxml4 msxml6 vcrun2022 fontsmooth=rgb winhttp win11 cabextract &&
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" setup_vkd3d_proton install &&
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" setup_dxvk install &&
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q $DEFAULT_GFX &&
        force_windows_version
    fi
    #WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q --force vcrun2022
    #cd "$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c/users/$USER/Downloads/"
}

function dx9_setup() {
  local cfg=$DEFAULT_WORK_DIR_CACHE/NMachineSpecificOptions.xml
  cat > $cfg << EOL
<?xml version="1.0" encoding="UTF-16" standalone="no" ?>
<OptionGroups>
  <BootstrapOptionsGroup SchemaVersion="2" ToolTip="Special preferences that require the application to be restarted after a change." UserName="Bootstrap">
    <driverOptionId ToolTip="The driver used to display the graphics" UserName="Graphics driver" Value="VirtualDeviceDx9"/></BootstrapOptionsGroup>
</OptionGroups>
EOL

  roaming_="${ROOTFOLDER}/wineprefixes/default/drive_c/users/$USER/AppData/Roaming/Autodesk/Neutron Platform/Options"
  local_="${ROOTFOLDER}/wineprefixes/default/drive_c/users/$USER/AppData/Local/Autodesk/Neutron Platform/Options"
  data_="${ROOTFOLDER}/wineprefixes/default/drive_c/users/$USER/Application Data/Autodesk/Neutron Platform/Options"
  #
  mkdir -p roaming_
  mkdir -p local_
  mkdir -p data_
  #
  cp $cfg roaming_
  cp $cfg local_
  cp $cfg data_
}

function install_webview2() {
  force_windows_version
  WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine "$DOWNLOADS/$DEFAULT_WEBVIEW_INSTALLER_NAME" /install
}

function install_fusion() {
  local fexec="$(find "$DEFAULT_WORK_DIR_WINE_PREFIX" -name Fusion360.exe)"
  if [ ! -f "$fexec" ]; then
    WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" timeout -k 10m 9m wine "$DOWNLOADS/$DEFAULT_FUSION_INSTALLER_NAME"
    local fexec="$(find "$DEFAULT_WORK_DIR_WINE_PREFIX" -name Fusion360.exe)"
    echo "WINEPREFIX=\"$DEFAULT_WORK_DIR_WINE_PREFIX\" wine \"$fexec\"" >> "$DEFAULT_BOX"
  fi
}

function install_fusion_addons() {
    local addons="AdditiveAssistant.bundle-win64.msi ParameterIO_win64.msi OctoPrint_for_Fusion360-win64.msi HelicalGear_win64.msi AirfoilTools_win64.msi"

    for addon in $addons
    do
        local tmp="$DEFAULT_WORK_DIR_CACHE/$addon"
        local dl="$DOWNLOADS/$addon"

        if [ ! -f "$tmp" ]; then
            curl https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/extensions/$obj --output "$tmp"
        fi
        cp "$tmp" "$dl"
        WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine msiexec /i "$dl"
    done
}

function get_production_id() {
  local exec_path=$(find $DEFAULT_WORK_DIR_WINE_PREFIX -name AdskIdentityManager.exe)
  local id_path=${exec_path%"/Autodesk Identity"*}
  local current_id=${id_path#*"production/"}
  echo $current_id
}

function asdkidmgr_opener () {
local desktop_file="$DEFAULT_WORK_DIR_CACHE/asdkidmgr_opener.desktop"
  if [ ! -f "$desktop_file" ]; then
    cat > $desktop_file << EOL
[Desktop Entry]
Type=Application
Name=adskidmgr Scheme Handler
Exec=env WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine C:\\\\Program\\ Files\\\\Autodesk\\\\webdeploy\\\\production\\\\$(get_production_id)\\\\Autodesk Identity Manager\\\\AdskIdentityManager.exe %u
StartupNotify=false
MimeType=x-scheme-handler/adskidmgr;
EOL
xdg-mime default adskidmgr-opener.desktop x-scheme-handler/adskidmgr
  fi
}

function authorize() {
  local bin_name=AdskIdentityManager.exe
  local login=$(cat "$DEFAULT_WORK_DIR_CACHE/login.txt")
  local exec_path=$(find $DEFAULT_WORK_DIR_WINE_PREFIX -name $bin_name -exec dirname {} \;)
  cd "$exec_path"
  WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine $bin_name $login
  cd -
}

function install_action() {
    init
    download_winetricks
    setup_winetricks
    download_webview2_installer
    download_fusion_installer
    install_webview2
    install_fusion
    asdkidmgr_opener
#    install_fusion_addons
    force_windows_version
}

function list_tricks () {
  WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" list-all
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
  list_tricks)
    list_tricks
    ;;
  gen_opener)
    asdkidmgr_opener
    ;;
  auth)
    authorize
    ;;
esac
