#! /bin/bash
# Author @Łukasz Buśko
# Licence: MPLv2
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#

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
# dxvk dx9/10/11 (vulkan)
# vkd3d - dx12 9 (vulkan)
# leave empty (opengl)
DEFAULT_GFX=galliumnine
DEFAULT_BOX="$DEFAULT_WORK_DIR_WINE_PREFIX/box-run.sh"
FORCE_ARCH=win64

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

function replace_file_with_backup() {
  local infile="$1"
  local outfile="$2"
  local backup_file="$outfile.backup"
  if [ ! -f "$infile" ]; then
    echo "Files does not exist $infile"
    exit 1
  fi
  if [ ! -f "$backup_file" ];
  then
    cp -p "$outfile" "$backup_file"
  fi
  cp "$infile" "$outfile"
}

function force_windows_version() {
  WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine winecfg -v win11
}

function setup_winetricks() {
    if [ ! -d "$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c" ]; then
        WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q sandbox win11 &&
        WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q $DEFAULT_GFX atmlib cjkfonts corefonts dotnet48 fontsmooth=rgb gdiplus msxml4 msxml6 vcrun2022 winhttp &&
        force_windows_version
        ### fixes goes here
        WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q bcp47langs=disabled
    fi
}

function glx_config_generator() {
  local cfg=$DEFAULT_WORK_DIR_CACHE/NMachineSpecificOptions.xml
  cat > $cfg << EOL
<?xml version="1.0" encoding="UTF-16" standalone="no" ?>
<OptionGroups>
  <BootstrapOptionsGroup SchemaVersion="2" ToolTip="Special preferences that require the application to be restarted after a change." UserName="Bootstrap">
    <driverOptionId ToolTip="The driver used to display the graphics" UserName="Graphics driver" Value="$1"/></BootstrapOptionsGroup>
</OptionGroups>
EOL

  local roaming_="$DEFAULT_WORK_DIR_WINE_PREFIX/drive_c/users/$USER/AppData/Roaming/Autodesk/Neutron Platform/Options"
  #
  mkdir -p "$roaming_"
  # configuration modfication goes here
  network_issue_protein_assets $cfg
  #
  cp $cfg "$roaming_"
}

function glx_setup () {
  case $DEFAULT_GFX in
    dxvk) # direct 11 or opengl
      # "VirtualDeviceGLCore"
      glx_config_generator "VirtualDeviceDx11"
      ;;
    galliumnine) # directx 9
      glx_config_generator "VirtualDeviceDx9"
      ;;
    vkd3d) # not supported yet
      glx_config_generator "VirtualDeviceDx12"
      ;;
    *)
      glx_config_generator "VirtualDeviceGLCore"
      ;;
  esac
}

function network_issue_protein_assets() {
  sed -ie "5i <NetworkOptionGroup SchemaVersion=\"2\" ToolTip=\"These are a set of options that are used for network access.\" UserName=\"Network\"> \n\
\t\t<SSLVerifyPeerOptionId ToolTip=\"Verify that the Autodesk Fusion 360 client can validate the server SSL Certificate.\" UserName=\"Server Verification\" Value=\"TrustAllServers\"/></NetworkOptionGroup>" $cfg
}

function issue_qt6_webengine() {
  local QT6_WEBENGINECORE_URL="https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/extras/patched-dlls/Qt6WebEngineCore.dll.7z"
  download $QT6_WEBENGINECORE_URL Qt6WebEngineCore.dll.7z
  if [ ! -f $DEFAULT_WORK_DIR_CACHE/Qt6WebEngineCore.dll ];
  then
    7z e -o$DEFAULT_WORK_DIR_CACHE $DEFAULT_WORK_DIR_CACHE/Qt6WebEngineCore.dll.7z
  fi
  local Qt6WebEngineCoreFile=$(find $DEFAULT_WORK_DIR_WINE_PREFIX -name Qt6WebEngineCore.dll)
  replace_file_with_backup $DEFAULT_WORK_DIR_CACHE/Qt6WebEngineCore.dll "$Qt6WebEngineCoreFile"
}

function issue_ai_functions() {
  local SIAPPDLL_URL="https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/extras/patched-dlls/siappdll.dll"
  download $SIAPPDLL_URL siappdll.dll
  local Qt6WebEngineCoreFile=$(find $DEFAULT_WORK_DIR_WINE_PREFIX -name Qt6WebEngineCore.dll)
  local siappdll_path="$(dirname "$Qt6WebEngineCoreFile")/siappdll.dll"
  if [ ! -f "$siappdll_path" ]; then
    cp $DEFAULT_WORK_DIR_CACHE/siappdll.dll "$siappdll_path"
  fi
}

function install_webview2() {
  force_windows_version
  WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine "$DOWNLOADS/$DEFAULT_WEBVIEW_INSTALLER_NAME" /silent /install
}

function install_fusion() {
  local fexec="$(find "$DEFAULT_WORK_DIR_WINE_PREFIX" -name Fusion360.exe)"
  if [ ! -f "$fexec" ]; then
    WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" timeout -k 10m 9m wine "$DOWNLOADS/$DEFAULT_FUSION_INSTALLER_NAME" --quiet
    local fexec="$(find "$DEFAULT_WORK_DIR_WINE_PREFIX" -name Fusion360.exe)"
    echo "WINEARCH=$FORCE_ARCH WINEPREFIX=\"$DEFAULT_WORK_DIR_WINE_PREFIX\" wine \"$fexec\"" >> "$DEFAULT_BOX"
    glx_setup
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
        WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine msiexec /i "$dl"
    done
}

function get_production_id() {
  local exec_path=$(find $DEFAULT_WORK_DIR_WINE_PREFIX -name AdskIdentityManager.exe)
  local id_path=${exec_path%"/Autodesk Identity"*}
  local current_id=${id_path#*"production/"}
  echo $current_id
}

function asdkidmgr_opener () {
local adskidmgr=adskidmgr
local filename=$adskidmgr-opener.desktop
local desktop_file="$DEFAULT_WORK_DIR_CACHE/$filename"
local autodesk_desktop_install_path=$HOME/.local/share/applications/autodesk
  if [ ! -f "$desktop_file" ]; then
    cat > $desktop_file << EOL
[Desktop Entry]
Type=Application
Name=$adskidmgr Scheme Handler
Exec=env WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine "C:\Program Files\Autodesk\webdeploy\production\\$(get_production_id)\Autodesk Identity Manager\AdskIdentityManager.exe" %u
StartupNotify=false
MimeType=x-scheme-handler/adskidmgr;
EOL
  xdg-mime default adskidmgr-opener.desktop x-scheme-handler/adskidmgr
  desktop-file-install --dir=$autodesk_desktop_install_path $desktop_file
  update-desktop-database $autodesk_desktop_install_path
  fi
}

function authorize() {
  local bin_name=AdskIdentityManager.exe
  local login=$(cat "$DEFAULT_WORK_DIR_CACHE/login.txt")
  local exec_path=$(find $DEFAULT_WORK_DIR_WINE_PREFIX -name $bin_name -exec dirname {} \;)
  cd "$exec_path"
  WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" wine $bin_name $login
  cd -
}

function experimental() {
    WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" -q dxvk
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
    issue_qt6_webengine
    issue_ai_functions
}

function list_all_tricks () {
  WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" list-all
}

function list_installed_tricks () {
  WINEARCH=$FORCE_ARCH WINEPREFIX="$DEFAULT_WORK_DIR_WINE_PREFIX" sh "$DEFAULT_WORK_DIR_CACHE/winetricks" list-installed
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
  list_all_tricks)
    list_all_tricks
    ;;
  list_installed_tricks)
    list_installed_tricks
    ;;
  gen_opener)
    asdkidmgr_opener
    ;;
  auth)
    authorize
    ;;
  exp)
    experimental
    ;;
esac
