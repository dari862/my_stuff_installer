#!/usr/bin/env bash
set -Eeuo pipefail

# Initialize system
info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

file_version="3.14"
VERSION="${4-win11}"

if [ ! -f "/drivers.tar.xz" ];then
	export DEBCONF_NOWARNINGS="yes"
	export DEBIAN_FRONTEND="noninteractive"
	export DEBCONF_NONINTERACTIVE_SEEN="true"
	sudo apt-get update
	sudo apt-get --no-install-recommends -y install \
        	uuid-runtime wimtools genisoimage
	sudo apt-get clean

	sudo mkdir -p "/storage"
	mkdir -p /tmp/windows_installer
	
	wget https://github.com/qemus/virtiso/releases/download/v0.1.262/virtio-win-0.1.262.tar.xz -P /tmp/windows_installer
	mv -f /tmp/windows_installer/virtio-win-* /tmp/windows_installer/drivers.tar.xz
	chmod 664 /tmp/windows_installer/drivers.tar.xz
	
	sudo chown root:root /tmp/windows_installer/drivers.tar.xz
	sudo mv -f /tmp/windows_installer/drivers.tar.xz /
fi

: "${BOOT_MODE:="windows"}"

trap 'error "Status $? while: $BASH_COMMAND (line $LINENO/$BASH_LINENO)"' ERR

# Docker environment variables

: "${BOOT:=""}"           # URL of the ISO file
: "${DEBUG:="N"}"         # Disable debugging
: "${MACHINE:="q35"}"     # Machine selection
: "${ALLOCATE:=""}"       # Preallocate diskspace
: "${ARGUMENTS:=""}"      # Extra QEMU parameters
: "${BOOT_MODE:=""}"      # Boot system with UEFI
: "${BOOT_INDEX:="9"}"    # Boot index of CD drive

# Helper variables

STORAGE="/storage"

CPI=$(lscpu)
SYS=$(uname -r)

if ! grep -qi "socket(s)" <<< "$CPI"; then
  SOCKETS=1
else
  SOCKETS=$(echo "$CPI" | grep -m 1 -i 'socket(s)' | awk '{print $(2)}')
fi

# Check system

if [ ! -d "/dev/shm" ]; then
  error "Directory /dev/shm not found!" && exit 14
else
  [ ! -d "/run/shm" ] && ln -s /dev/shm /run/shm
fi

# Check folder

if [ ! -d "$STORAGE" ]; then
  error "Storage folder ($STORAGE) not found!" && exit 13
fi

# Print system info
SYS="${SYS/-generic/}"
FS=$(stat -f -c %T "$STORAGE")
FS="${FS/ext2\/ext3/ext4}"
# Check compatibilty

if [[ "${BOOT_MODE:-}" == "windows"* ]]; then
  if [[ "${FS,,}" == "btrfs" ]] && [[ "${SYS,,}" == *"-unraid"* ]]; then
    warn "you are using BTRFS on Unraid, this might introduce issues!"
  fi
fi


# Helper functions

hasDisk() {

  [ -b "/disk" ] && return 0
  [ -b "/disk1" ] && return 0
  [ -b "/dev/disk1" ] && return 0
  [ -b "${DEVICE:-}" ] && return 0

  [ -z "${DISK_NAME:-}" ] && DISK_NAME="data"
  [ -s "$STORAGE/$DISK_NAME.img" ]  && return 0
  [ -s "$STORAGE/$DISK_NAME.qcow2" ] && return 0

  return 1
}

# Initialize system
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
# Define versions

: "${XRES:=""}"
: "${YRES:=""}"
: "${VERIFY:=""}"
: "${REGION:=""}"
: "${MANUAL:=""}"
: "${REMOVE:=""}"
: "${VERSION:=""}"
: "${DETECTED:=""}"
: "${KEYBOARD:=""}"
: "${LANGUAGE:=""}"
: "${USERNAME:=""}"
: "${PASSWORD:=""}"

MIRRORS=4
PLATFORM="x64"

parseVersion() {

  if [[ "${VERSION}" == \"*\" || "${VERSION}" == \'*\' ]]; then
    VERSION="${VERSION:1:-1}"
  fi

  [ -z "$VERSION" ] && VERSION="win11"

  case "${VERSION,,}" in
    "11" | "11p" | "win11" | "win11p" | "windows11" | "windows 11" )
      VERSION="win11x64"
      ;;
    "11e" | "win11e" | "windows11e" | "windows 11e" )
      VERSION="win11x64-enterprise-eval"
      ;;
    "10" | "10p" | "win10" | "win10p" | "windows10" | "windows 10" )
      VERSION="win10x64"
      ;;
    "10e" | "win10e" | "windows10e" | "windows 10e" )
      VERSION="win10x64-enterprise-eval"
      ;;
    "8" | "8p" | "81" | "81p" | "8.1" | "win8" | "win8p" | "win81" | "win81p" | "windows 8" )
      VERSION="win81x64"
      ;;
    "8e" | "81e" | "8.1e" | "win8e" | "win81e" | "windows 8e" )
      VERSION="win81x64-enterprise-eval"
      ;;
    "7" | "7e" | "win7" | "win7e" | "windows7" | "windows 7" )
      VERSION="win7x64"
      [ -z "$DETECTED" ] && DETECTED="win7x64-enterprise"
      ;;
    "7u" | "win7u" | "windows7u" | "windows 7u" )
      VERSION="win7x64-ultimate"
      ;;
    "7x86" | "win7x86" | "windows7x86"  | "win7x86-enterprise" )
      VERSION="win7x86"
      [ -z "$DETECTED" ] && DETECTED="win7x86-enterprise"
      ;;
    "vista" | "winvista" | "windowsvista" | "windows vista" )
      VERSION="winvistax64"
      [ -z "$DETECTED" ] && DETECTED="winvistax64-enterprise"
      ;;
    "vistu" | "winvistu" | "windowsvistu" | "windows vistu" )
      VERSION="winvistax64-ultimate"
      ;;
    "vistax86" | "winvistax86" | "windowsvistax86"  | "winvistax86-enterprise" )
      VERSION="winvistax86"
      [ -z "$DETECTED" ] && DETECTED="winvistax86-enterprise"
      ;;
    "xp" | "xp32" | "xpx86" | "winxp" | "winxp86" | "windowsxp" | "windows xp" )
      VERSION="winxpx86"
      ;;
    "xp64" | "xpx64" | "winxp64" | "winxpx64" | "windowsxp64" | "windowsxpx64" )
      VERSION="winxpx64"
      ;;
    "25" | "2025" | "win25" | "win2025" | "windows2025" | "windows 2025" )
      VERSION="win2025-eval"
      ;;
    "22" | "2022" | "win22" | "win2022" | "windows2022" | "windows 2022" )
      VERSION="win2022-eval"
      ;;
    "19" | "2019" | "win19" | "win2019" | "windows2019" | "windows 2019" )
      VERSION="win2019-eval"
      ;;
    "16" | "2016" | "win16" | "win2016" | "windows2016" | "windows 2016" )
      VERSION="win2016-eval"
      ;;
    "2012" | "2012r2" | "win2012" | "win2012r2" | "windows2012" | "windows 2012" )
      VERSION="win2012r2-eval"
      ;;
    "2008" | "2008r2" | "win2008" | "win2008r2" | "windows2008" | "windows 2008" )
      VERSION="win2008r2"
      ;;
    "2003" | "2003r2" | "win2003" | "win2003r2" | "windows2003" | "windows 2003" )
      VERSION="win2003r2"
      ;;
    "core11" | "core 11" )
      VERSION="core11"
      [ -z "$DETECTED" ] && DETECTED="win11x64"
      ;;
    "tiny11" | "tiny 11" )
      VERSION="tiny11"
      [ -z "$DETECTED" ] && DETECTED="win11x64"
      ;;
   "tiny10" | "tiny 10" )
      VERSION="tiny10"
      [ -z "$DETECTED" ] && DETECTED="win10x64-ltsc"
      ;;
    "iot11" | "11iot" | "win11-iot" | "win11x64-iot" | "win11x64-enterprise-iot-eval" )
      VERSION="win11x64-enterprise-iot-eval"
      [ -z "$DETECTED" ] && DETECTED="win11x64-iot"
      ;;
    "iot10" | "10iot" | "win10-iot" | "win10x64-iot" | "win10x64-enterprise-iot-eval" )
      VERSION="win10x64-enterprise-iot-eval"
      [ -z "$DETECTED" ] && DETECTED="win10x64-iot"
      ;;
    "ltsc11" | "11ltsc" | "win11-ltsc" | "win11x64-ltsc" | "win11x64-enterprise-ltsc-eval" )
      VERSION="win11x64-enterprise-ltsc-eval"
      [ -z "$DETECTED" ] && DETECTED="win11x64-iot"
      ;;
    "ltsc10" | "10ltsc" | "win10-ltsc" | "win10x64-ltsc" | "win10x64-enterprise-ltsc-eval" )
      VERSION="win10x64-enterprise-ltsc-eval"
      [ -z "$DETECTED" ] && DETECTED="win10x64-ltsc"
      ;;
  esac

  return 0
}

getLanguage() {

  local id="$1"
  local ret="$2"
  local lang=""
  local desc=""
  local culture=""

  case "${id,,}" in
    "ar" | "ar-"* )
      lang="Arabic"
      desc="$lang"
      culture="ar-SA" ;;
    "gb" | "en-gb" )
      lang="English International"
      desc="English"
      culture="en-GB" ;;
    "en" | "en-"* )
      lang="English (United States)"
      desc="English"
      culture="en-US" ;;
  esac

  case "${ret,,}" in
    "desc" ) echo "$desc" ;;
    "name" ) echo "$lang" ;;
    "culture" ) echo "$culture" ;;
    *) echo "$desc";;
  esac

  return 0
}

parseLanguage() {

  REGION="${REGION//_/-/}"
  KEYBOARD="${KEYBOARD//_/-/}"
  LANGUAGE="${LANGUAGE//_/-/}"

  [ -z "$LANGUAGE" ] && LANGUAGE="en"

  case "${LANGUAGE,,}" in
    "arabic" | "arab" ) LANGUAGE="ar" ;;
    "english" | "gb" | "british" ) LANGUAGE="en" ;;
  esac

  local culture
  culture=$(getLanguage "$LANGUAGE" "culture")
  [ -n "$culture" ] && return 0

  error "Invalid LANGUAGE specified, value \"$LANGUAGE\" is not recognized!"
  return 1
}

printVersion() {

  local id="$1"
  local desc="$2"

  case "${id,,}" in
    "tiny11"* ) desc="Tiny 11" ;;
    "tiny10"* ) desc="Tiny 10" ;;
    "core11"* ) desc="Core 11" ;;
    "win7"* ) desc="Windows 7" ;;
    "win8"* ) desc="Windows 8" ;;
    "win10"* ) desc="Windows 10" ;;
    "win11"* ) desc="Windows 11" ;;
    "winxp"* ) desc="Windows XP" ;;
    "win9x"* ) desc="Windows ME" ;;
    "win98"* ) desc="Windows 98" ;;
    "win95"* ) desc="Windows 95" ;;
    "win2k"* ) desc="Windows 2000" ;;
    "winvista"* ) desc="Windows Vista" ;;
    "win2003"* ) desc="Windows Server 2003" ;;
    "win2008"* ) desc="Windows Server 2008" ;;
    "win2012"* ) desc="Windows Server 2012" ;;
    "win2016"* ) desc="Windows Server 2016" ;;
    "win2019"* ) desc="Windows Server 2019" ;;
    "win2022"* ) desc="Windows Server 2022" ;;
    "win2025"* ) desc="Windows Server 2025" ;;
  esac

  if [ -z "$desc" ]; then
    desc="Windows"
    [[ "${PLATFORM,,}" != "x64" ]] && desc="$desc for ${PLATFORM}"
  fi

  echo "$desc"
  return 0
}

printEdition() {

  local id="$1"
  local desc="$2"
  local result=""
  local edition=""

  result=$(printVersion "$id" "x")
  [[ "$result" == "x" ]] && echo "$desc" && return 0

  case "${id,,}" in
    *"-home" )
      edition="Home"
      ;;
    *"-starter" )
      edition="Starter"
      ;;
    *"-ultimate" )
      edition="Ultimate"
      ;;
    *"-enterprise" )
      edition="Enterprise"
      ;;
    *"-education" )
      edition="Education"
      ;;
    *"-iot" | *"-iot-eval" )
      edition="IoT"
      ;;
    *"-ltsc" | *"-ltsc-eval" )
      edition="LTSC"
      ;;
    *"-enterprise-eval" )
      edition="Enterprise (Evaluation)"
      ;;
    "win7"* )
      edition="Professional"
      ;;
    "win8"* | "win10"* | "win11"* )
      edition="Pro"
      ;;
    "winxp"* )
      edition="Professional"
      ;;
    "winvista"* )
      edition="Business"
      ;;
    "win2025"* | "win2022"* | "win2019"* | "win2016"* )
      edition="Standard"
      ;;
    "win2012"* | "win2008"* | "win2003"* )
      edition="Standard"
      ;;
  esac

  [ -n "$edition" ] && result+=" $edition"

  echo "$result"
  return 0
}

fromFile() {

  local id=""
  local desc="$1"
  local file="${1,,}"
  local arch="${PLATFORM,,}"

  case "${file// /_}" in
    *"_x64_"* | *"_x64."*)
      arch="x64"
      ;;
    *"_x86_"* | *"_x86."*)
      arch="x86"
      ;;
    *"_arm64_"* | *"_arm64."*)
      arch="arm64"
      ;;
  esac

  case "${file// /_}" in
    "win7"* | "win_7"* | *"windows7"* | *"windows_7"* )
      id="win7${arch}"
      ;;
    "win8"* | "win_8"* | *"windows8"* | *"windows_8"* )
      id="win81${arch}"
      ;;
    "win10"*| "win_10"* | *"windows10"* | *"windows_10"* )
      id="win10${arch}"
      ;;
    "win11"* | "win_11"* | *"windows11"* | *"windows_11"* )
      id="win11${arch}"
      ;;
    *"winxp"* | *"win_xp"* | *"windowsxp"* | *"windows_xp"* )
      id="winxpx86"
      ;;
    *"winvista"* | *"win_vista"* | *"windowsvista"* | *"windows_vista"* )
      id="winvista${arch}"
      ;;
    "tiny11core"* | "tiny11_core"* | "tiny_11_core"* )
      id="core11"
      ;;
    "tiny11"* | "tiny_11"* )
      id="tiny11"
      ;;
    "tiny10"* | "tiny_10"* )
      id="tiny10"
      ;;
    *"server2025"* | *"server_2025"* )
      id="win2025"
      ;;
    *"server2022"* | *"server_2022"* )
      id="win2022"
      ;;
    *"server2019"* | *"server_2019"* )
      id="win2019"
      ;;
    *"server2016"* | *"server_2016"* )
      id="win2016"
      ;;
    *"server2012"* | *"server_2012"* )
      id="win2012r2"
      ;;
    *"server2008"* | *"server_2008"* )
      id="win2008r2"
      ;;
    *"server2003"* | *"server_2003"* )
      id="win2003r2"
      ;;
  esac

  if [ -n "$id" ]; then
    desc=$(printVersion "$id" "$desc")
  fi

  echo "$desc"
  return 0
}

fromName() {

  local id=""
  local name="$1"
  local arch="$2"

  case "${name,,}" in
    *"server 2025"* ) id="win2025" ;;
    *"server 2022"* ) id="win2022" ;;
    *"server 2019"* ) id="win2019" ;;
    *"server 2016"* ) id="win2016" ;;
    *"server 2012"* ) id="win2012r2" ;;
    *"server 2008"* ) id="win2008r2" ;;
    *"windows 7"* ) id="win7${arch}" ;;
    *"windows 8"* ) id="win81${arch}" ;;
    *"windows 10"* ) id="win10${arch}" ;;
    *"windows 11"* ) id="win11${arch}" ;;
    *"windows vista"* ) id="winvista${arch}" ;;
  esac

  echo "$id"
  return 0
}

getVersion() {

  local id
  local name="$1"
  local arch="$2"

  id=$(fromName "$name" "$arch")

  case "${id,,}" in
    "win7"* | "winvista"* )
        case "${name,,}" in
          *" home"* ) id="$id-home" ;;
          *" starter"* ) id="$id-starter" ;;
          *" ultimate"* ) id="$id-ultimate" ;;
          *" enterprise"* ) id="$id-enterprise" ;;
        esac
      ;;
    "win8"* )
        case "${name,,}" in
          *" enterprise evaluation"* ) id="$id-enterprise-eval" ;;
          *" enterprise"* ) id="$id-enterprise" ;;
        esac
      ;;
    "win10"* | "win11"* )
       case "${name,,}" in
          *" iot"* ) id="$id-iot" ;;
          *" ltsc"* ) id="$id-ltsc" ;;
          *" home"* ) id="$id-home" ;;
          *" education"* ) id="$id-education" ;;
          *" enterprise evaluation"* ) id="$id-enterprise-eval" ;;
          *" enterprise"* ) id="$id-enterprise" ;;
        esac
      ;;
    "win2025"* | "win2022"* | "win2019"* | "win2016"* | "win2012"* | "win2008"* )
       case "${name,,}" in
          *" evaluation"* ) id="$id-eval" ;;
        esac
      ;;
  esac

  echo "$id"
  return 0
}

switchEdition() {

  local id="$1"

  case "${id,,}" in
    "win11${PLATFORM,,}-enterprise-eval" )
      DETECTED="win11${PLATFORM,,}-enterprise"
      ;;
    "win10${PLATFORM,,}-enterprise-eval" )
      DETECTED="win10${PLATFORM,,}-enterprise"
      ;;
    "win81${PLATFORM,,}-enterprise-eval" )
      DETECTED="win81${PLATFORM,,}-enterprise"
      ;;
    "win2025-eval" ) DETECTED="win2025" ;;
    "win2022-eval" ) DETECTED="win2022" ;;
    "win2019-eval" ) DETECTED="win2019" ;;
    "win2016-eval" ) DETECTED="win2016" ;;
    "win2012r2-eval" ) DETECTED="win2012r2" ;;
    "win2008r2-eval" ) DETECTED="win2008r2" ;;
  esac

  return 0
}

getMido() {

  local id="$1"
  local lang="$2"
  local ret="$3"
  local sum=""
  local size=""

  [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0

  case "${id,,}" in
    "win11x64" )
      size=6812706816
      sum="36de5ecb7a0daa58dce68c03b9465a543ed0f5498aa8ae60ab45fb7c8c4ae402"
      ;;
    "win11x64-enterprise-eval" )
      size=6209064960
      sum="c8dbc96b61d04c8b01faf6ce0794fdf33965c7b350eaa3eb1e6697019902945c"
      ;;
    "win11x64-enterprise-ltsc-eval" )
      size=4428627968
      sum="8abf91c9cd408368dc73aab3425d5e3c02dae74900742072eb5c750fc637c195"
      ;;
    "win11x64-enterprise-iot-eval" )
      size=4428627968
      sum="8abf91c9cd408368dc73aab3425d5e3c02dae74900742072eb5c750fc637c195"
      ;;
    "win10x64" )
      size=6140975104
      sum="a6f470ca6d331eb353b815c043e327a347f594f37ff525f17764738fe812852e"
      ;;
    "win10x64-enterprise-eval" )
      size=5550497792
      sum="ef7312733a9f5d7d51cfa04ac497671995674ca5e1058d5164d6028f0938d668"
      ;;
    "win10x64-enterprise-ltsc-eval" )
      size=4898582528
      sum="e4ab2e3535be5748252a8d5d57539a6e59be8d6726345ee10e7afd2cb89fefb5"
      ;;
    "win81x64" )
      size=4320526336
      sum="d8333cf427eb3318ff6ab755eb1dd9d433f0e2ae43745312c1cd23e83ca1ce51"
      ;;
    "win81x64-enterprise-eval" )
      size=3961473024
      sum="2dedd44c45646c74efc5a028f65336027e14a56f76686a4631cf94ffe37c72f2"
      ;;
    "win2025-eval" )
      size=5307996160
      sum="16442d1c0509bcbb25b715b1b322a15fb3ab724a42da0f384b9406ca1c124ed4"
      ;;
    "win2022-eval" )
      size=5044094976
      sum="3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255325"
      ;;
    "win2019-eval" )
      size=5652088832
      sum="6dae072e7f78f4ccab74a45341de0d6e2d45c39be25f1f5920a2ab4f51d7bcbb"
     ;;
    "win2016-eval" )
      size=6972221440
      sum="1ce702a578a3cb1ac3d14873980838590f06d5b7101c5daaccbac9d73f1fb50f"
      ;;
    "win2012r2-eval" )
      size=4542291968
      sum="6612b5b1f53e845aacdf96e974bb119a3d9b4dcb5b82e65804ab7e534dc7b4d5"
      ;;
    "win2008r2" )
      size=3166840832
      sum="30832ad76ccfa4ce48ccb936edefe02079d42fb1da32201bf9e3a880c8ed6312"
      ;;
  esac

  case "${ret,,}" in
    "sum" ) echo "$sum" ;;
    "size" ) echo "$size" ;;
    *) echo "";;
  esac

  return 0
}

getLink1() {

  # Fallbacks for users who cannot connect to the Microsoft servers

  local id="$1"
  local lang="$2"
  local ret="$3"
  local url=""
  local sum=""
  local size=""
  local host="https://dl.bobpony.com/windows"

  [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0

  case "${id,,}" in
    "win11x64" | "win11x64-enterprise" | "win11x64-enterprise-eval" )
      size=5946128384
      sum="5bb1459034f50766ee480d895d751af73a4af30814240ae32ebc5633546a5af7"
      url="11/en-us_windows_11_23h2_x64.iso"
      ;;
    "win11x64-iot" | "win11x64-enterprise-iot-eval" )
      [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0
      size=4821989376
      sum="e8f1431c4e6289b3997c20eadbb2576670300bb6e1cf8948b5d7af179010a962"
      url="11/26100.1.240331-1435.ge_release_CLIENT_ENTERPRISES_OEM_x64FRE_en-us.iso"
      ;;
    "win11x64-ltsc" | "win11x64-enterprise-ltsc-eval" )
      [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0
      size=4821989376
      sum="e8f1431c4e6289b3997c20eadbb2576670300bb6e1cf8948b5d7af179010a962"
      url="11/26100.1.240331-1435.ge_release_CLIENT_ENTERPRISES_OEM_x64FRE_en-us.iso"
      ;;
    "win10x64" | "win10x64-enterprise" | "win10x64-enterprise-eval" )
      size=5623582720
      sum="57371545d752a79a8a8b163b209c7028915da661de83516e06ddae913290a855"
      url="10/en-us_windows_10_22h2_x64.iso"
      ;;
    "win10x64-iot" | "win10x64-enterprise-iot-eval" )
      size=4851668992
      sum="a0334f31ea7a3e6932b9ad7206608248f0bd40698bfb8fc65f14fc5e4976c160"
      url="10/en-us_windows_10_iot_enterprise_ltsc_2021_x64_dvd_257ad90f.iso"
      ;;
    "win10x64-ltsc" | "win10x64-enterprise-ltsc-eval" )
      size=4899461120
      sum="c90a6df8997bf49e56b9673982f3e80745058723a707aef8f22998ae6479597d"
      url="10/en-us_windows_10_enterprise_ltsc_2021_x64_dvd_d289cf96.iso"
      ;;
    "win81x64" )
      size=4320526336
      sum="d8333cf427eb3318ff6ab755eb1dd9d433f0e2ae43745312c1cd23e83ca1ce51"
      url="8.x/8.1/en_windows_8.1_with_update_x64_dvd_6051480.iso"
      ;;
    "win2025" | "win2025-eval" )
      size=5307176960
      sum="2293897341febdcea599f5412300b470b5288c6fd2b89666a7b27d283e8d3cf3"
      url="server/2025/en-us_windows_server_2025_preview_x64_dvd_ce9eb1a5.iso"
      ;;
    "win2022" | "win2022-eval" )
      size=5365624832
      sum="c3c57bb2cf723973a7dcfb1a21e97dfa035753a7f111e348ad918bb64b3114db"
      url="server/2022/en-us_windows_server_2022_updated_jan_2024_x64_dvd_2b7a0c9f.iso"
      ;;
    "win2019" | "win2019-eval" )
      size=5575774208
      sum="0067afe7fdc4e61f677bd8c35a209082aa917df9c117527fc4b2b52a447e89bb"
      url="server/2019/en-us_windows_server_2019_updated_aug_2021_x64_dvd_a6431a28.iso"
      ;;
    "win2016" | "win2016-eval" )
      size=6006587392
      sum="af06e5483c786c023123e325cea4775050324d9e1366f46850b515ae43f764be"
      url="server/2016/en_windows_server_2016_updated_feb_2018_x64_dvd_11636692.iso"
      ;;
    "win2012r2" | "win2012r2-eval" )
      size=5397889024
      sum="f351e89eb88a96af4626ceb3450248b8573e3ed5924a4e19ea891e6003b62e4e"
      url="server/2012r2/en_windows_server_2012_r2_with_update_x64_dvd_6052708-004.iso"
      ;;
    "win2008r2" | "win2008r2-eval" )
      size=3166584832
      sum="dfd9890881b7e832a927c38310fb415b7ea62ac5a896671f2ce2a111998f0df8"
      url="server/2008r2/en_windows_server_2008_r2_with_sp1_x64_dvd_617601-018.iso"
      ;;
    "win7x64" | "win7x64-enterprise" )
      size=3182604288
      sum="ee69f3e9b86ff973f632db8e01700c5724ef78420b175d25bae6ead90f6805a7"
      url="7/en_windows_7_enterprise_with_sp1_x64_dvd_u_677651.iso"
      ;;
    "win7x64-ultimate" )
      size=3320836096
      sum="0b738b55a5ea388ad016535a5c8234daf2e5715a0638488ddd8a228a836055a1"
      url="7/en_windows_7_with_sp1_x64.iso"
      ;;
    "win7x86" | "win7x86-enterprise" )
      size=2434502656
      sum="8bdd46ff8cb8b8de9c4aba02706629c8983c45e87da110e64e13be17c8434dad"
      url="7/en_windows_7_enterprise_with_sp1_x86_dvd_u_677710.iso"
      ;;
    "win7x86-ultimate" )
      size=2564411392
      sum="99f3369c90160816be07093dbb0ac053e0a84e52d6ed1395c92ae208ccdf67e5"
      url="7/en_windows_7_with_sp1_x86.iso"
      ;;
    "winvistax64-ultimate" )
      size=3861460992
      sum="edf9f947c5791469fd7d2d40a5dcce663efa754f91847aa1d28ed7f585675b78"
      url="vista/en_windows_vista_sp2_x64_dvd_342267.iso"
      ;;
    "winvistax86-ultimate" )
      size=3243413504
      sum="9c36fed4255bd05a8506b2da88f9aad73643395e155e609398aacd2b5276289c"
      url="vista/en_windows_vista_with_sp2_x86_dvd_342266.iso"
      ;;
    "winxpx86" )
      size=617756672
      sum="62b6c91563bad6cd12a352aa018627c314cfc5162d8e9f8af0756a642e602a46"
      url="xp/professional/en_windows_xp_professional_with_service_pack_3_x86_cd_x14-80428.iso"
      ;;
    "winxpx64" )
      size=614166528
      sum="8fac68e1e56c64ad9a2aa0ad464560282e67fa4f4dd51d09a66f4e548eb0f2d6"
      url="xp/professional/en_win_xp_pro_x64_vl.iso"
      ;;
  esac

  case "${ret,,}" in
    "sum" ) echo "$sum" ;;
    "size" ) echo "$size" ;;
    *) [ -n "$url" ] && echo "$host/$url";;
  esac

  return 0
}

getLink2() {

  local id="$1"
  local lang="$2"
  local ret="$3"
  local url=""
  local sum=""
  local size=""
  local host="https://files.dog/MSDN"

  [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0

  case "${id,,}" in
    "win81x64" )
      size=4320526336
      sum="d8333cf427eb3318ff6ab755eb1dd9d433f0e2ae43745312c1cd23e83ca1ce51"
      url="Windows%208.1%20with%20Update/en_windows_8.1_with_update_x64_dvd_6051480.iso"
      ;;
    "win81x64-enterprise" | "win81x64-enterprise-eval" )
      size=4139163648
      sum="c3c604c03677504e8905090a8ce5bb1dde76b6fd58e10f32e3a25bef21b2abe1"
      url="Windows%208.1%20with%20Update/en_windows_8.1_enterprise_with_update_x64_dvd_6054382.iso"
      ;;
    "win2012r2" | "win2012r2-eval" )
      size=5397889024
      sum="f351e89eb88a96af4626ceb3450248b8573e3ed5924a4e19ea891e6003b62e4e"
      url="Windows%20Server%202012%20R2%20with%20Update/en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso"
      ;;
    "win2008r2" | "win2008r2-eval" )
      size=3166584832
      sum="dfd9890881b7e832a927c38310fb415b7ea62ac5a896671f2ce2a111998f0df8"
      url="Windows%20Server%202008%20R2/en_windows_server_2008_r2_with_sp1_x64_dvd_617601.iso"
      ;;
    "win7x64" | "win7x64-enterprise" )
      size=3182604288
      sum="ee69f3e9b86ff973f632db8e01700c5724ef78420b175d25bae6ead90f6805a7"
      url="Windows%207/en_windows_7_enterprise_with_sp1_x64_dvd_u_677651.iso"
      ;;
    "win7x64-ultimate" )
      size=3320903680
      sum="36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808"
      url="Windows%207/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso"
      ;;
    "win7x86" | "win7x86-enterprise" )
      size=2434502656
      sum="8bdd46ff8cb8b8de9c4aba02706629c8983c45e87da110e64e13be17c8434dad"
      url="Windows%207/en_windows_7_enterprise_with_sp1_x86_dvd_u_677710.iso"
      ;;
    "win7x86-ultimate" )
      size=2564476928
      sum="e2c009a66d63a742941f5087acae1aa438dcbe87010bddd53884b1af6b22c940"
      url="Windows%207/en_windows_7_ultimate_with_sp1_x86_dvd_u_677460.iso"
      ;;
    "winvistax64" | "winvistax64-enterprise" )
      size=3205953536
      sum="0a0cd511b3eac95c6f081419c9c65b12317b9d6a8d9707f89d646c910e788016"
      url="Windows%20Vista/en_windows_vista_enterprise_sp2_x64_dvd_342332.iso"
      ;;
    "winvistax64-ultimate" )
      size=3861460992
      sum="edf9f947c5791469fd7d2d40a5dcce663efa754f91847aa1d28ed7f585675b78"
      url="Windows%20Vista/en_windows_vista_sp2_x64_dvd_342267.iso"
      ;;
    "winvistax86" | "winvistax86-enterprise" )
      size=2420981760
      sum="54e2720004041e7db988a391543ea5228b0affc28efcf9303d2d0ff9402067f5"
      url="Windows%20Vista/en_windows_vista_enterprise_sp2_x86_dvd_342329.iso"
      ;;
    "winvistax86-ultimate" )
      size=3243413504
      sum="9c36fed4255bd05a8506b2da88f9aad73643395e155e609398aacd2b5276289c"
      url="Windows%20Vista/en_windows_vista_with_sp2_x86_dvd_342266.iso"
      ;;
    "win2003r2" )
      size=652367872
      sum="74245cba888f935b138b106c2744bec7f392925b472358960a0b5643cd6abb32"
      url="Windows%20Server%202003%20R2/en_win_srv_2003_r2_standard_x64_with_sp2_cd1_x13-05757.iso"
      ;;
    "winxpx86" )
      size=617756672
      sum="62b6c91563bad6cd12a352aa018627c314cfc5162d8e9f8af0756a642e602a46"
      url="Windows%20XP/en_windows_xp_professional_with_service_pack_3_x86_cd_x14-80428.iso"
      ;;
    "winxpx64" )
      size=614166528
      sum="8fac68e1e56c64ad9a2aa0ad464560282e67fa4f4dd51d09a66f4e548eb0f2d6"
      url="Windows%20XP/en_win_xp_pro_x64_vl.iso"
      ;;
  esac

  case "${ret,,}" in
    "sum" ) echo "$sum" ;;
    "size" ) echo "$size" ;;
    *) [ -n "$url" ] && echo "$host/$url";;
  esac

  return 0
}

getLink3() {

  # Fallbacks for users who cannot connect to the Microsoft servers

  local id="$1"
  local lang="$2"
  local ret="$3"
  local url=""
  local sum=""
  local size=""
  local host="https://drive.massgrave.dev"
  local s22="windows_server_2022_updated_july_2024_x64_dvd_fee121d6"  
  local c11="windows_11_consumer_editions_version_23h2_updated_july_2024_x64_dvd_13e3dd80"
  local b11="windows_11_business_editions_version_23h2_updated_july_2024_x64_dvd"
  local c10="windows_10_consumer_editions_version_22h2_updated_july_2024_x64_dvd_3245b006"
  local b10="windows_10_business_editions_version_22h2_updated_july_2024_x64_dvd"

  culture=$(getLanguage "$lang" "culture")

  case "${id,,}" in
    "win11x64" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar-sa_${c11}.iso" ;;
        "bg" | "bg-"* ) url="bg-bg_${c11}.iso" ;;
        "cs" | "cs-"* ) url="cs-cz_${c11}.iso" ;;
        "da" | "da-"* ) url="da-dk_${c11}.iso" ;;
        "de" | "de-"* ) url="de-de_${c11}.iso" ;;
        "el" | "el-"* ) url="el-gr_${c11}.iso" ;;
        "gb" | "en-gb" ) url="en-gb_${c11}.iso" ;;
        "en" | "en-"* )
          size=7165775872
          sum="b84e497c019e95ba9aee9da3d86e679454cba1a426593711f0f4d426f48fc845"
          url="en-us_${c11}.iso" ;;
        "mx" | "es-mx" ) url="es-mx_${c11}.iso" ;;
        "es" | "es-"* ) url="es-es_${c11}.iso" ;;
        "et" | "et-"* ) url="et-ee_${c11}.iso" ;;
        "fi" | "fi-"* ) url="fi-fi_${c11}.iso" ;;
        "ca" | "fr-ca" ) url="fr-ca_${c11}.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_${c11}.iso" ;;
        "he" | "he-"* ) url="he-il_${c11}.iso" ;;
        "hr" | "hr-"* ) url="hr-hr_${c11}.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_${c11}.iso" ;;
        "it" | "it-"* ) url="it-it_${c11}.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_${c11}.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_${c11}.iso" ;;
        "lt" | "lt-"* ) url="lt-lt_${c11}.iso" ;;
        "lv" | "lv-"* ) url="lv-lv_${c11}.iso" ;;
        "nb" | "nb-"* ) url="nb-no_${c11}.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_${c11}.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_${c11}.iso" ;;
        "br" | "pt-br" ) url="pt-br_${c11}.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_${c11}.iso" ;;
        "ro" | "ro-"* ) url="ro-ro_${c11}.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_${c11}.iso" ;;
        "sk" | "sk-"* ) url="sk-sk_${c11}.iso" ;;
        "sl" | "sl-"* ) url="sl-si_${c11}.iso" ;;
        "sr" | "sr-"* ) url="sr-latn-rs_${c11}.iso" ;;
        "sv" | "sv-"* ) url="sv-se_${c11}.iso" ;;
        "th" | "th-"* ) url="th-th_${c11}.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_${c11}.iso" ;;
        "uk" | "uk-"* ) url="uk-ua_${c11}.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_${c11}.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_${c11}.iso" ;;
      esac
      ;;
    "win11x64-enterprise" | "win11x64-enterprise-eval" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar-sa_${b11}_39c553d6.iso" ;;
        "bg" | "bg-"* ) url="bg-bg_${b11}_eb13b76c.iso" ;;
        "cs" | "cs-"* ) url="cs-cz_${b11}_397728ab.iso" ;;
        "da" | "da-"* ) url="da-dk_${b11}_4df23c83.iso" ;;
        "de" | "de-"* ) url="de-de_${b11}_9a27972d.iso" ;;
        "el" | "el-"* ) url="el-gr_${b11}_c8957889.iso" ;;
        "gb" | "en-gb" ) url="en-gb_${b11}_deb8a337.iso" ;;
        "en" | "en-"* )
          size=7035154432
          sum="651e02efa8efe5c3ed6f99f91a934604add93d0fa28a5e7e29898d47bc92eba5"
          url="en-us_${b11}_5a07b6a4.iso" ;;
        "mx" | "es-mx" ) url="es-mx_${b11}_2c5e4da9.iso" ;;
        "es" | "es-"* ) url="es-es_${b11}_4fde1bd2.iso" ;;
        "et" | "et-"* ) url="et-ee_${b11}_dbdba8e6.iso" ;;
        "fi" | "fi-"* ) url="fi-fi_${b11}_84ef21ee.iso" ;;
        "ca" | "fr-ca" ) url="fr-ca_${b11}_2cfbb3d3.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_${b11}_f922413d.iso" ;;
        "he" | "he-"* ) url="he-il_${b11}_277cd23a.iso" ;;
        "hr" | "hr-"* ) url="hr-hr_${b11}_65579a9d.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_${b11}_3e8637f5.iso" ;;
        "it" | "it-"* ) url="it-it_${b11}_da0f0ca1.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_${b11}_86b39781.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_${b11}_0a970f66.iso" ;;
        "lt" | "lt-"* ) url="lt-lt_${b11}_8429ce4c.iso" ;;
        "lv" | "lv-"* ) url="lv-lv_${b11}_8eb4a9a7.iso" ;;
        "nb" | "nb-"* ) url="nb-no_${b11}_2ebae5cb.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_${b11}_6dba664c.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_${b11}_829bf56a.iso" ;;
        "br" | "pt-br" ) url="pt-br_${b11}_cd555922.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_${b11}_ad4cf2e0.iso" ;;
        "ro" | "ro-"* ) url="ro-ro_${b11}_2340f750.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_${b11}_4207eb9f.iso" ;;
        "sk" | "sk-"* ) url="sk-sk_${b11}_a1ba40e5.iso" ;;
        "sl" | "sl-"* ) url="sl-si_${b11}_282cc939.iso" ;;
        "sr" | "sr-"* ) url="sr-latn-rs_${b11}_b4915859.iso" ;;
        "sv" | "sv-"* ) url="sv-se_${b11}_879e706a.iso" ;;
        "th" | "th-"* ) url="th-th_${b11}_f51e12b1.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_${b11}_b52351ad.iso" ;;
        "uk" | "uk-"* ) url="uk-ua_${b11}_4a9948b3.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_${b11}_75853f9b.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_${b11}_8c3fbaa8.iso" ;;
      esac
      ;;
    "win11x64-iot" | "win11x64-enterprise-iot-eval" )
      [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0
      size=4821989376
      sum="e8f1431c4e6289b3997c20eadbb2576670300bb6e1cf8948b5d7af179010a962"
      url="26100.1.240331-1435.ge_release_CLIENTENTERPRISE_OEM_x64FRE_en-us.iso"
      ;;
    "win11x64-ltsc" | "win11x64-enterprise-ltsc-eval" )
      [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0
      size=4821989376
      sum="e8f1431c4e6289b3997c20eadbb2576670300bb6e1cf8948b5d7af179010a962"
      url="26100.1.240331-1435.ge_release_CLIENTENTERPRISE_OEM_x64FRE_en-us.iso"
      ;;
    "win10x64" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar-sa_${c10}.iso" ;;
        "bg" | "bg-"* ) url="bg-bg_${c10}.iso" ;;
        "cs" | "cs-"* ) url="cs-cz_${c10}.iso" ;;
        "da" | "da-"* ) url="da-dk_${c10}.iso" ;;
        "de" | "de-"* ) url="de-de_${c10}.iso" ;;
        "el" | "el-"* ) url="el-gr_${c10}.iso" ;;
        "gb" | "en-gb" ) url="en-gb_${c10}.iso" ;;
        "en" | "en-"* )
          size=7151144960
          sum="2eda4701d3e4061eccfdf0ad264b69392e67e2a29fef9eb7d7a57150b08e87e0"
          url="en-us_${c10}.iso" ;;
        "mx" | "es-mx" ) url="es-mx_${c10}.iso" ;;
        "es" | "es-"* ) url="es-es_${c10}.iso" ;;
        "et" | "et-"* ) url="et-ee_${c10}.iso" ;;
        "fi" | "fi-"* ) url="fi-fi_${c10}.iso" ;;
        "ca" | "fr-ca" ) url="fr-ca_${c10}.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_${c10}.iso" ;;
        "he" | "he-"* ) url="he-il_${c10}.iso" ;;
        "hr" | "hr-"* ) url="hr-hr_${c10}.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_${c10}.iso" ;;
        "it" | "it-"* ) url="it-it_${c10}.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_${c10}.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_${c10}.iso" ;;
        "lt" | "lt-"* ) url="lt-lt_${c10}.iso" ;;
        "lv" | "lv-"* ) url="lv-lv_${c10}.iso" ;;
        "nb" | "nb-"* ) url="nb-no_${c10}.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_${c10}.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_${c10}.iso" ;;
        "br" | "pt-br" ) url="pt-br_${c10}.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_${c10}.iso" ;;
        "ro" | "ro-"* ) url="ro-ro_${c10}.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_${c10}.iso" ;;
        "sk" | "sk-"* ) url="sk-sk_${c10}.iso" ;;
        "sl" | "sl-"* ) url="sl-si_${c10}.iso" ;;
        "sr" | "sr-"* ) url="sr-latn-rs_${c10}.iso" ;;
        "sv" | "sv-"* ) url="sv-se_${c10}.iso" ;;
        "th" | "th-"* ) url="th-th_${c10}.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_${c10}.iso" ;;
        "uk" | "uk-"* ) url="uk-ua_${c10}.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_${c10}.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_${c10}.iso" ;;
      esac
      ;;
    "win10x64-enterprise" | "win10x64-enterprise-eval" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar-sa_${b10}_c297cc0d.iso" ;;
        "bg" | "bg-"* ) url="bg-bg_${b10}_30c9ad0e.iso" ;;
        "cs" | "cs-"* ) url="cs-cz_${b10}_0a65fb0a.iso" ;;
        "da" | "da-"* ) url="da-dk_${b10}_57521eab.iso" ;;
        "de" | "de-"* ) url="de-de_${b10}_9beb944c.iso" ;;
        "el" | "el-"* ) url="el-gr_${b10}_4f7921a5.iso" ;;
        "gb" | "en-gb" ) url="en-gb_${b10}_77325f32.iso" ;;
        "en" | "en-"* )
          size=6978310144
          sum="7847abd6f39abd02dc8089c4177d354f9eb66fa0ee2fe8ae20e596e675d1ab67"
          url="en-us_${b10}_c004521a.iso" ;;
        "mx" | "es-mx" ) url="es-mx_${b10}_56d48916.iso" ;;
        "es" | "es-"* ) url="es-es_${b10}_4e057a75.iso" ;;
        "et" | "et-"* ) url="et-ee_${b10}_8e8c70da.iso" ;;
        "fi" | "fi-"* ) url="fi-fi_${b10}_023ba9da.iso" ;;
        "ca" | "fr-ca" ) url="fr-ca_${b10}_e4b0fd01.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_${b10}_8a45f12e.iso" ;;
        "he" | "he-"* ) url="he-il_${b10}_8ce094aa.iso" ;;
        "hr" | "hr-"* ) url="hr-hr_${b10}_668d9ec4.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_${b10}_7f70b22c.iso" ;;
        "it" | "it-"* ) url="it-it_${b10}_3c49c82b.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_${b10}_383799d9.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_${b10}_f0249763.iso" ;;
        "lt" | "lt-"* ) url="lt-lt_${b10}_a13593c6.iso" ;;
        "lv" | "lv-"* ) url="lv-lv_${b10}_4a00695c.iso" ;;
        "nb" | "nb-"* ) url="nb-no_${b10}_c949d1f1.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_${b10}_bb1f8a40.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_${b10}_26b503cc.iso" ;;
        "br" | "pt-br" ) url="pt-br_${b10}_10757645.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_${b10}_07f873cd.iso" ;;
        "ro" | "ro-"* ) url="ro-ro_${b10}_e2c973f8.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_${b10}_e86552ca.iso" ;;
        "sk" | "sk-"* ) url="sk-sk_${b10}_03d84a11.iso" ;;
        "sl" | "sl-"* ) url="sl-si_${b10}_ad745ec0.iso" ;;
        "sr" | "sr-"* ) url="sr-latn-rs_${b10}_36a086b8.iso" ;;
        "sv" | "sv-"* ) url="sv-se_${b10}_756d5d5b.iso" ;;
        "th" | "th-"* ) url="th-th_${b10}_cf4bb364.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_${b10}_3ceed34b.iso" ;;
        "uk" | "uk-"* ) url="uk-ua_${b10}_e6a5235d.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_${b10}_fac0f45b.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_${b10}_53d015e8.iso" ;;
      esac
      ;;
    "win10x64-ltsc" | "win10x64-enterprise-ltsc-eval" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar-sa_windows_10_enterprise_ltsc_2021_x64_dvd_60bc2a7a.iso" ;;
        "bg" | "bg-"* ) url="bg-bg_windows_10_enterprise_ltsc_2021_x64_dvd_b0887275.iso" ;;
        "cs" | "cs-"* ) url="cs-cz_windows_10_enterprise_ltsc_2021_x64_dvd_d624c653.iso" ;;
        "da" | "da-"* ) url="da-dk_windows_10_enterprise_ltsc_2021_x64_dvd_6ec511bb.iso" ;;
        "de" | "de-"* ) url="de-de_windows_10_enterprise_ltsc_2021_x64_dvd_71796d33.iso" ;;
        "el" | "el-"* ) url="el-gr_windows_10_enterprise_ltsc_2021_x64_dvd_c83eab34.iso" ;;
        "gb" | "en-gb" ) url="en-gb_windows_10_enterprise_ltsc_2021_x64_dvd_7fe51fe8.iso" ;;
        "en" | "en-"* )
          size=4899461120
          sum="c90a6df8997bf49e56b9673982f3e80745058723a707aef8f22998ae6479597d"
          url="en-us_windows_10_enterprise_ltsc_2021_x64_dvd_d289cf96.iso" ;;
        "mx" | "es-mx" ) url="es-mx_windows_10_enterprise_ltsc_2021_x64_dvd_f6aaf384.iso" ;;
        "es" | "es-"* ) url="es-es_windows_10_enterprise_ltsc_2021_x64_dvd_51d721ea.iso" ;;
        "et" | "et-"* ) url="et-ee_windows_10_enterprise_ltsc_2021_x64_dvd_012a5c50.iso" ;;
        "fi" | "fi-"* ) url="fi-fi_windows_10_enterprise_ltsc_2021_x64_dvd_551582d9.iso" ;;
        "ca" | "fr-ca" ) url="fr-ca_windows_10_enterprise_ltsc_2021_x64_dvd_2770e649.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_windows_10_enterprise_ltsc_2021_x64_dvd_bda01eb0.iso" ;;
        "he" | "he-"* ) url="he-il_windows_10_enterprise_ltsc_2021_x64_dvd_3a55ecd6.iso" ;;
        "hr" | "hr-"* ) url="hr-hr_windows_10_enterprise_ltsc_2021_x64_dvd_f5085b75.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_windows_10_enterprise_ltsc_2021_x64_dvd_d541ddb3.iso" ;;
        "it" | "it-"* ) url="it-it_windows_10_enterprise_ltsc_2021_x64_dvd_0c1aa034.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_windows_10_enterprise_ltsc_2021_x64_dvd_ef58c6a1.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_windows_10_enterprise_ltsc_2021_x64_dvd_6d26f398.iso" ;;
        "lt" | "lt-"* ) url="lt-lt_windows_10_enterprise_ltsc_2021_x64_dvd_9ffbbd5b.iso" ;;
        "lv" | "lv-"* ) url="lv-lv_windows_10_enterprise_ltsc_2021_x64_dvd_6c89d2e0.iso" ;;
        "nb" | "nb-"* ) url="nb-no_windows_10_enterprise_ltsc_2021_x64_dvd_c65c51a5.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_windows_10_enterprise_ltsc_2021_x64_dvd_88f53466.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_windows_10_enterprise_ltsc_2021_x64_dvd_eff40776.iso" ;;
        "br" | "pt-br" ) url="pt-br_windows_10_enterprise_ltsc_2021_x64_dvd_f318268e.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_windows_10_enterprise_ltsc_2021_x64_dvd_f2e9b6a0.iso" ;;
        "ro" | "ro-"* ) url="ro-ro_windows_10_enterprise_ltsc_2021_x64_dvd_ae2284d6.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_windows_10_enterprise_ltsc_2021_x64_dvd_5044a1e7.iso" ;;
        "sk" | "sk-"* ) url="sk-sk_windows_10_enterprise_ltsc_2021_x64_dvd_d6c64c5f.iso" ;;
        "sl" | "sl-"* ) url="sl-si_windows_10_enterprise_ltsc_2021_x64_dvd_ec090386.iso" ;;
        "sr" | "sr-"* ) url="sr-latn-rs_windows_10_enterprise_ltsc_2021_x64_dvd_2d2f8815.iso" ;;
        "sv" | "sv-"* ) url="sv-se_windows_10_enterprise_ltsc_2021_x64_dvd_9a28bb6b.iso" ;;
        "th" | "th-"* ) url="th-th_windows_10_enterprise_ltsc_2021_x64_dvd_b7ed34d6.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_windows_10_enterprise_ltsc_2021_x64_dvd_e55b1896.iso" ;;
        "uk" | "uk-"* ) url="uk-ua_windows_10_enterprise_ltsc_2021_x64_dvd_816da3c3.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_windows_10_enterprise_ltsc_2021_x64_dvd_80dba877.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_windows_10_enterprise_ltsc_2021_x64_dvd_033b7312.iso" ;;
      esac
      ;;
    "win10x64-iot" | "win10x64-enterprise-iot-eval" )
      [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0
      size=4851668992
      sum="a0334f31ea7a3e6932b9ad7206608248f0bd40698bfb8fc65f14fc5e4976c160"
      url="en-us_windows_10_iot_enterprise_ltsc_2021_x64_dvd_257ad90f.iso"
      ;;
    "win81x64-enterprise" | "win81x64-enterprise-eval" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_8.1_enterprise_with_update_x64_dvd_6050360.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_8.1_enterprise_with_update_x64_dvd_6050367.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_8.1_enterprise_with_update_x64_dvd_6050393.iso" ;;
        "da" | "da-"* ) url="da_windows_8.1_enterprise_with_update_x64_dvd_6050394.iso" ;;
        "de" | "de-"* ) url="de_windows_8.1_enterprise_with_update_x64_dvd_6050501.iso" ;;
        "el" | "el-"* ) url="el_windows_8.1_enterprise_with_update_x64_dvd_6050503.iso" ;;
        "gb" | "en-gb" ) url="en-gb_windows_8.1_enterprise_with_update_x64_dvd_6054383.iso" ;;
        "en" | "en-"* )
          size=4139163648
          sum="c3c604c03677504e8905090a8ce5bb1dde76b6fd58e10f32e3a25bef21b2abe1"
          url="en_windows_8.1_enterprise_with_update_x64_dvd_6054382.iso" ;;
        "es" | "es-"* ) url="es_windows_8.1_enterprise_with_update_x64_dvd_6050578.iso" ;;
        "et" | "et-"* ) url="et_windows_8.1_enterprise_with_update_x64_dvd_6054384.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_8.1_enterprise_with_update_x64_dvd_6050497.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_8.1_enterprise_with_update_x64_dvd_6050499.iso" ;;
        "he" | "he-"* ) url="he_windows_8.1_enterprise_with_update_x64_dvd_6050504.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_8.1_enterprise_with_update_x64_dvd_6050391.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_8.1_enterprise_with_update_x64_dvd_6050505.iso" ;;
        "it" | "it-"* ) url="it_windows_8.1_enterprise_with_update_x64_dvd_6050507.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_8.1_enterprise_with_update_x64_dvd_6050508.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_8.1_enterprise_with_update_x64_dvd_6050509.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_8.1_enterprise_with_update_x64_dvd_6050511.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_8.1_enterprise_with_update_x64_dvd_6050510.iso" ;;
        "nb" | "nb-"* ) url="nb_windows_8.1_enterprise_with_update_x64_dvd_6050512.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_8.1_enterprise_with_update_x64_dvd_6054381.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_8.1_enterprise_with_update_x64_dvd_6050515.iso" ;;
        "br" | "pt-br" ) url="pt_windows_8.1_enterprise_with_update_x64_dvd_6050521.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_8.1_enterprise_with_update_x64_dvd_6050526.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_8.1_enterprise_with_update_x64_dvd_6050534.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_8.1_enterprise_with_update_x64_dvd_6050542.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_8.1_enterprise_with_update_x64_dvd_6050562.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_8.1_enterprise_with_update_x64_dvd_6050570.iso" ;;
        "sr" | "sr-"* ) url="sr-latn_windows_8.1_enterprise_with_update_x64_dvd_6050553.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_8.1_enterprise_with_update_x64_dvd_6050590.iso" ;;
        "th" | "th-"* ) url="th_windows_8.1_enterprise_with_update_x64_dvd_6050602.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_8.1_enterprise_with_update_x64_dvd_6050609.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_8.1_enterprise_with_update_x64_dvd_6050618.iso" ;;
        "zh-hk" ) url="hk_windows_8.1_enterprise_with_update_x64_dvd_6050380.iso" ;;
        "zh-tw" ) url="tw_windows_8.1_enterprise_with_update_x64_dvd_6050387.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_8.1_enterprise_with_update_x64_dvd_6050374.iso" ;;
      esac
      ;;
    "win2025" | "win2025-eval" )
      case "${culture,,}" in
        "cs" | "cs-"* ) url="cs-cz_windows_server_2025_preview_x64_dvd_8b1f5b49.iso" ;;
        "de" | "de-"* ) url="de-de_windows_server_2025_preview_x64_dvd_1c3dfe1c.iso" ;;
        "en" | "en-"* )
          size=5307176960
          sum="2293897341febdcea599f5412300b470b5288c6fd2b89666a7b27d283e8d3cf3"
          url="en-us_windows_server_2025_preview_x64_dvd_ce9eb1a5.iso" ;;
        "es" | "es-"* ) url="es-es_windows_server_2025_preview_x64_dvd_b07cc858.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_windows_server_2025_preview_x64_dvd_036e8a78.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_windows_server_2025_preview_x64_dvd_2d5d77e5.iso" ;;
        "it" | "it-"* ) url="it-it_windows_server_2025_preview_x64_dvd_eaccac73.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_windows_server_2025_preview_x64_dvd_62f802be.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_windows_server_2025_preview_x64_dvd_e2c3e8f0.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_windows_server_2025_preview_x64_dvd_314b4ed1.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_windows_server_2025_preview_x64_dvd_be4b099e.iso" ;;
        "br" | "pt-br" ) url="pt-br_windows_server_2025_preview_x64_dvd_993c803a.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_windows_server_2025_preview_x64_dvd_869aa534.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_windows_server_2025_preview_x64_dvd_5ada1817.iso" ;;
        "sv" | "sv-"* ) url="sv-se_windows_server_2025_preview_x64_dvd_5fafd4f7.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_windows_server_2025_preview_x64_dvd_3aab7fda.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_windows_server_2025_preview_x64_dvd_9b147dcd.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_windows_server_2025_preview_x64_dvd_a12bb0bf.iso" ;;
      esac
      ;;
    "win2022" | "win2022-eval" )
      case "${culture,,}" in
        "cs" | "cs-"* ) url="cs-cz_${s22}.iso" ;;
        "de" | "de-"* ) url="de-de_${s22}.iso" ;;
        "en" | "en-"* )
          size=5933062144
          sum="5b6c4fab1027ed15cbd4179b8a41b184304ba362fa0053b3bad6ac070ee74281"
          url="en-us_${s22}.iso" ;;
        "es" | "es-"* ) url="es-es_${s22}.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_${s22}.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_${s22}.iso" ;;
        "it" | "it-"* ) url="it-it_${s22}.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_${s22}.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_${s22}.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_${s22}.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_${s22}.iso" ;;
        "br" | "pt-br" ) url="pt-br_${s22}.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_${s22}.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_${s22}.iso" ;;
        "sv" | "sv-"* ) url="sv-se_${s22}.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_${s22}.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_${s22}.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_${s22}.iso" ;;
      esac
      ;;
    "win2019" | "win2019-eval" )
      case "${culture,,}" in
        "cs" | "cs-"* ) url="cs-cz_windows_server_2019_x64_dvd_3781c31c.iso" ;;
        "de" | "de-"* ) url="de-de_windows_server_2019_x64_dvd_132f7aa4.iso" ;;
        "en" | "en-"* )
          size=5651695616
          sum="ea247e5cf4df3e5829bfaaf45d899933a2a67b1c700a02ee8141287a8520261c"
          url="en-us_windows_server_2019_x64_dvd_f9475476.iso" ;;
        "es" | "es-"* ) url="es-es_windows_server_2019_x64_dvd_3ce0fd9e.iso" ;;
        "fr" | "fr-"* ) url="fr-fr_windows_server_2019_x64_dvd_f6f6acf6.iso" ;;
        "hu" | "hu-"* ) url="hu-hu_windows_server_2019_x64_dvd_1d834c46.iso" ;;
        "it" | "it-"* ) url="it-it_windows_server_2019_x64_dvd_454267de.iso" ;;
        "ja" | "ja-"* ) url="ja-jp_windows_server_2019_x64_dvd_3899c3a3.iso" ;;
        "ko" | "ko-"* ) url="ko-kr_windows_server_2019_x64_dvd_84101c0a.iso" ;;
        "nl" | "nl-"* ) url="nl-nl_windows_server_2019_x64_dvd_f69d914e.iso" ;;
        "pl" | "pl-"* ) url="pl-pl_windows_server_2019_x64_dvd_a50263e1.iso" ;;
        "br" | "pt-br" ) url="pt-br_windows_server_2019_x64_dvd_aee8c1c2.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_windows_server_2019_x64_dvd_464373e8.iso" ;;
        "ru" | "ru-"* ) url="ru-ru_windows_server_2019_x64_dvd_e02b76ba.iso" ;;
        "sv" | "sv-"* ) url="sv-se_windows_server_2019_x64_dvd_48c1aeff.iso" ;;
        "tr" | "tr-"* ) url="tr-tr_windows_server_2019_x64_dvd_b51af600.iso" ;;
        "zh-hk" | "zh-tw" ) url="zh-tw_windows_server_2019_x64_dvd_a4c80409.iso" ;;
        "zh" | "zh-"* ) url="zh-cn_windows_server_2019_x64_dvd_19d65722.iso" ;;
      esac
      ;;
    "win2016" | "win2016-eval" )
      case "${culture,,}" in
        "cs" | "cs-"* ) url="cs_windows_server_2016_vl_x64_dvd_11636699.iso" ;;
        "de" | "de-"* ) url="de_windows_server_2016_vl_x64_dvd_11636696.iso" ;;
        "en" | "en-"* )
          size=6003804160
          sum="47919ce8b4993f531ca1fa3f85941f4a72b47ebaa4d3a321fecf83ca9d17e6b8"
          url="en_windows_server_2016_vl_x64_dvd_11636701.iso" ;;
        "es" | "es-"* ) url="es_windows_server_2016_vl_x64_dvd_11636712.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_server_2016_vl_x64_dvd_11636729.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_server_2016_vl_x64_dvd_11636720.iso" ;;
        "it" | "it-"* ) url="it_windows_server_2016_vl_x64_dvd_11636710.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_server_2016_vl_x64_dvd_11645964.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_server_2016_vl_x64_dvd_11636709.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_server_2016_vl_x64_dvd_11636731.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_server_2016_vl_x64_dvd_11636719.iso" ;;
        "br" | "pt-br" ) url="pt_windows_server_2016_vl_x64_dvd_11636697.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_server_2016_vl_x64_dvd_11637454.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_server_2016_vl_x64_dvd_11636694.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_server_2016_vl_x64_dvd_11636706.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_server_2016_vl_x64_dvd_11636725.iso" ;;
        "zh-hk" | "zh-tw" ) url="ct_windows_server_2016_vl_x64_dvd_11636717.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_server_2016_vl_x64_dvd_11636695.iso" ;;
      esac
      ;;
    "win2012r2" | "win2012r2-eval" )
      case "${culture,,}" in
        "cs" | "cs-"* ) url="cs_windows_server_2012_r2_vl_with_update_x64_dvd_6052752.iso" ;;
        "de" | "de-"* ) url="de_windows_server_2012_r2_vl_with_update_x64_dvd_6052780.iso" ;;
        "en" | "en-"* )
          size=5400115200
          sum="0e883ce28eb5c6f58a3a3007be978d43edb1035a4585506c1c4504c9e143408d"
          url="en_windows_server_2012_r2_vl_with_update_x64_dvd_6052766.iso" ;;
        "es" | "es-"* ) url="es_windows_server_2012_r2_vl_with_update_x64_dvd_6052831.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_server_2012_r2_vl_with_update_x64_dvd_6052772.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_server_2012_r2_vl_with_update_x64_dvd_6052786.iso" ;;
        "it" | "it-"* ) url="it_windows_server_2012_r2_vl_with_update_x64_dvd_6052792.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_server_2012_r2_vl_with_update_x64_dvd_6052800.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_server_2012_r2_vl_with_update_x64_dvd_6052806.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_server_2012_r2_vl_with_update_x64_dvd_6052760.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_server_2012_r2_vl_with_update_x64_dvd_6052815.iso" ;;
        "br" | "pt-br" ) url="pt_windows_server_2012_r2_vl_with_update_x64_dvd_6052819.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_server_2012_r2_vl_with_update_x64_dvd_6052823.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_server_2012_r2_vl_with_update_x64_dvd_6052827.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_server_2012_r2_vl_with_update_x64_dvd_6052835.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_server_2012_r2_vl_with_update_x64_dvd_6052838.iso" ;;
        "zh-hk" ) url="hk_windows_server_2012_r2_vl_with_update_x64_dvd_6052739.iso" ;;
        "zh-tw" ) url="tw_windows_server_2012_r2_vl_with_update_x64_dvd_6052746.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_server_2012_r2_vl_with_update_x64_dvd_6052729.iso" ;;
      esac
      ;;
    "win2008r2" | "win2008r2-eval" )
      case "${culture,,}" in
        "cs" | "cs-"* ) url="cs_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617402.iso" ;;
        "de" | "de-"* ) url="de_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617404.iso" ;;
        "en" | "en-"* )
          size=3166720000
          sum="9b0cd5b11cc2e92badb74450f0cac03006d3c63a2ada36cb1eb95c1bf4b2608f"
          url="en_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617403.iso" ;;
        "es" | "es-"* ) url="es_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617410.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617392.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617415.iso" ;;
        "it" | "it-"* ) url="it_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_619596.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_631466.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617409.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617395.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617397.iso" ;;
        "br" | "pt-br" ) url="pt_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617394.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617411.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617421.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617400.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617416.iso" ;;
        "zh-hk" ) url="hk_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617386.iso" ;;
        "zh-tw" ) url="tw_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617405.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_server_2008_r2_with_sp1_vl_build_x64_dvd_617396.iso" ;;
      esac
      ;;
    "win7x64" | "win7x64-enterprise" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_7_enterprise_with_sp1_x64_dvd_u_677643.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_7_enterprise_with_sp1_x64_dvd_u_677644.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_7_enterprise_with_sp1_x64_dvd_u_677646.iso" ;;
        "da" | "da-"* ) url="da_windows_7_enterprise_with_sp1_x64_dvd_u_677648.iso" ;;
        "de" | "de-"* ) url="de_windows_7_enterprise_with_sp1_x64_dvd_u_677649.iso" ;;
        "el" | "el-"* ) url="el_windows_7_enterprise_with_sp1_x64_dvd_u_677650.iso" ;;
        "en" | "en-"* )
          size=3182604288
          sum="ee69f3e9b86ff973f632db8e01700c5724ef78420b175d25bae6ead90f6805a7"
          url="en_windows_7_enterprise_with_sp1_x64_dvd_u_677651.iso" ;;
        "es" | "es-"* ) url="es_windows_7_enterprise_with_sp1_x64_dvd_u_677652.iso" ;;
        "et" | "et-"* ) url="et_windows_7_enterprise_with_sp1_x64_dvd_u_677653.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_7_enterprise_with_sp1_x64_dvd_u_677655.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_7_enterprise_with_sp1_x64_dvd_u_677656.iso" ;;
        "he" | "he-"* ) url="he_windows_7_enterprise_with_sp1_x64_dvd_u_677657.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_7_enterprise_with_sp1_x64_dvd_u_677658.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_7_enterprise_with_sp1_x64_dvd_u_677659.iso" ;;
        "it" | "it-"* ) url="it_windows_7_enterprise_with_sp1_x64_dvd_u_677660.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_7_enterprise_with_sp1_x64_dvd_u_677662.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_7_enterprise_k_with_sp1_x64_dvd_u_677728.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_7_enterprise_with_sp1_x64_dvd_u_677663.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_7_enterprise_with_sp1_x64_dvd_u_677664.iso" ;;
        "nb" | "nb-"* ) url="no_windows_7_enterprise_with_sp1_x64_dvd_u_677665.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_7_enterprise_with_sp1_x64_dvd_u_677666.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_7_enterprise_with_sp1_x64_dvd_u_677667.iso" ;;
        "br" | "pt-br" ) url="pt_windows_7_enterprise_with_sp1_x64_dvd_u_677668.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_7_enterprise_with_sp1_x64_dvd_u_677669.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_7_enterprise_with_sp1_x64_dvd_u_677670.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_7_enterprise_with_sp1_x64_dvd_u_677671.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_7_enterprise_with_sp1_x64_dvd_u_677673.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_7_enterprise_with_sp1_x64_dvd_u_677674.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_7_enterprise_with_sp1_x64_dvd_u_677675.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_7_enterprise_with_sp1_x64_dvd_u_677676.iso" ;;
        "th" | "th-"* ) url="th_windows_7_enterprise_with_sp1_x64_dvd_u_677678.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_7_enterprise_with_sp1_x64_dvd_u_677681.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_7_enterprise_with_sp1_x64_dvd_u_677683.iso" ;;
        "zh-hk" ) url="hk_windows_7_enterprise_with_sp1_x64_dvd_u_677687.iso" ;;
        "zh-tw" ) url="tw_windows_7_enterprise_with_sp1_x64_dvd_u_677689.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_7_enterprise_with_sp1_x64_dvd_u_677685.iso" ;;
      esac
      ;;
    "win7x64-ultimate" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_7_ultimate_with_sp1_x64_dvd_u_677345.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_7_ultimate_with_sp1_x64_dvd_u_677363.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_7_ultimate_with_sp1_x64_dvd_u_677376.iso" ;;
        "da" | "da-"* ) url="da_windows_7_ultimate_with_sp1_x64_dvd_u_677294.iso" ;;
        "de" | "de-"* ) url="de_windows_7_ultimate_with_sp1_x64_dvd_u_677306.iso" ;;
        "el" | "el-"* ) url="el_windows_7_ultimate_with_sp1_x64_dvd_u_677318.iso" ;;
        "en" | "en-"* )
          size=3320903680
          sum="36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808"
          url="en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso" ;;
        "es" | "es-"* ) url="es_windows_7_ultimate_with_sp1_x64_dvd_u_677350.iso" ;;
        "et" | "et-"* ) url="et_windows_7_ultimate_with_sp1_x64_dvd_u_677368.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_7_ultimate_with_sp1_x64_dvd_u_677378.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_7_ultimate_with_sp1_x64_dvd_u_677299.iso" ;;
        "he" | "he-"* ) url="he_windows_7_ultimate_with_sp1_x64_dvd_u_677312.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_7_ultimate_with_sp1_x64_dvd_u_677324.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_7_ultimate_with_sp1_x64_dvd_u_677338.iso" ;;
        "it" | "it-"* ) url="it_windows_7_ultimate_with_sp1_x64_dvd_u_677356.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_7_ultimate_with_sp1_x64_dvd_u_677372.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_7_ultimate_k_with_sp1_x64_dvd_u_677502.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_7_ultimate_with_sp1_x64_dvd_u_677379.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_7_ultimate_with_sp1_x64_dvd_u_677302.iso" ;;
        "nb" | "nb-"* ) url="no_windows_7_ultimate_with_sp1_x64_dvd_u_677314.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_7_ultimate_with_sp1_x64_dvd_u_677325.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_7_ultimate_with_sp1_x64_dvd_u_677341.iso" ;;
        "br" | "pt-br" ) url="pt_windows_7_ultimate_with_sp1_x64_dvd_u_677358.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_7_ultimate_with_sp1_x64_dvd_u_677373.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_7_ultimate_with_sp1_x64_dvd_u_677380.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_7_ultimate_with_sp1_x64_dvd_u_677391.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_7_ultimate_with_sp1_x64_dvd_u_677393.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_7_ultimate_with_sp1_x64_dvd_u_677396.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_7_ultimate_with_sp1_x64_dvd_u_677398.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_7_ultimate_with_sp1_x64_dvd_u_677400.iso" ;;
        "th" | "th-"* ) url="th_windows_7_ultimate_with_sp1_x64_dvd_u_677402.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_7_ultimate_with_sp1_x64_dvd_u_677404.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_7_ultimate_with_sp1_x64_dvd_u_677406.iso" ;;
        "zh-hk" ) url="hk_windows_7_ultimate_with_sp1_x64_dvd_u_677411.iso" ;;
        "zh-tw" ) url="tw_windows_7_ultimate_with_sp1_x64_dvd_u_677414.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_7_ultimate_with_sp1_x64_dvd_u_677408.iso" ;;
      esac
      ;;
    "win7x86" | "win7x86-enterprise" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_7_enterprise_with_sp1_x86_dvd_u_677691.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_7_enterprise_with_sp1_x86_dvd_u_677693.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_7_enterprise_with_sp1_x86_dvd_u_677695.iso" ;;
        "da" | "da-"* ) url="da_windows_7_enterprise_with_sp1_x86_dvd_u_677698.iso" ;;
        "de" | "de-"* ) url="de_windows_7_enterprise_with_sp1_x86_dvd_u_677702.iso" ;;
        "el" | "el-"* ) url="el_windows_7_enterprise_with_sp1_x86_dvd_u_677706.iso" ;;
        "en" | "en-"* )
          size=2434502656
          sum="8bdd46ff8cb8b8de9c4aba02706629c8983c45e87da110e64e13be17c8434dad"
          url="en_windows_7_enterprise_with_sp1_x86_dvd_u_677710.iso" ;;
        "es" | "es-"* ) url="es_windows_7_enterprise_with_sp1_x86_dvd_u_677714.iso" ;;
        "et" | "et-"* ) url="et_windows_7_enterprise_with_sp1_x86_dvd_u_677718.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_7_enterprise_with_sp1_x86_dvd_u_677722.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_7_enterprise_with_sp1_x86_dvd_u_677727.iso" ;;
        "he" | "he-"* ) url="he_windows_7_enterprise_with_sp1_x86_dvd_u_677733.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_7_enterprise_with_sp1_x86_dvd_u_677739.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_7_enterprise_with_sp1_x86_dvd_u_677744.iso" ;;
        "it" | "it-"* ) url="it_windows_7_enterprise_with_sp1_x86_dvd_u_677749.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_7_enterprise_with_sp1_x86_dvd_u_677757.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_7_enterprise_k_with_sp1_x86_dvd_u_677732.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_7_enterprise_with_sp1_x86_dvd_u_677764.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_7_enterprise_with_sp1_x86_dvd_u_677677.iso" ;;
        "nb" | "nb-"* ) url="no_windows_7_enterprise_with_sp1_x86_dvd_u_677679.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_7_enterprise_with_sp1_x86_dvd_u_677682.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_7_enterprise_with_sp1_x86_dvd_u_677684.iso" ;;
        "br" | "pt-br" ) url="pt_windows_7_enterprise_with_sp1_x86_dvd_u_677686.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_7_enterprise_with_sp1_x86_dvd_u_677688.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_7_enterprise_with_sp1_x86_dvd_u_677690.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_7_enterprise_with_sp1_x86_dvd_u_677692.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_7_enterprise_with_sp1_x86_dvd_u_677694.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_7_enterprise_with_sp1_x86_dvd_u_677696.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_7_enterprise_with_sp1_x86_dvd_u_677699.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_7_enterprise_with_sp1_x86_dvd_u_677701.iso" ;;
        "th" | "th-"* ) url="th_windows_7_enterprise_with_sp1_x86_dvd_u_677705.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_7_enterprise_with_sp1_x86_dvd_u_677708.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_7_enterprise_with_sp1_x86_dvd_u_677712.iso" ;;
        "zh-hk" ) url="hk_windows_7_enterprise_with_sp1_x86_dvd_u_677720.iso" ;;
        "zh-tw" ) url="tw_windows_7_enterprise_with_sp1_x86_dvd_u_677723.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_7_enterprise_with_sp1_x86_dvd_u_677716.iso" ;;
      esac
      ;;
    "win7x86-ultimate" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_7_ultimate_with_sp1_x86_dvd_u_677448.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_7_ultimate_with_sp1_x86_dvd_u_677450.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_7_ultimate_with_sp1_x86_dvd_u_677452.iso" ;;
        "da" | "da-"* ) url="da_windows_7_ultimate_with_sp1_x86_dvd_u_677454.iso" ;;
        "de" | "de-"* ) url="de_windows_7_ultimate_with_sp1_x86_dvd_u_677456.iso" ;;
        "el" | "el-"* ) url="el_windows_7_ultimate_with_sp1_x86_dvd_u_677458.iso" ;;
        "en" | "en-"* )
          size=2564476928
          sum="e2c009a66d63a742941f5087acae1aa438dcbe87010bddd53884b1af6b22c940"
          url="en_windows_7_ultimate_with_sp1_x86_dvd_u_677460.iso" ;;
        "es" | "es-"* ) url="es_windows_7_ultimate_with_sp1_x86_dvd_u_677462.iso" ;;
        "et" | "et-"* ) url="et_windows_7_ultimate_with_sp1_x86_dvd_u_677464.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_7_ultimate_with_sp1_x86_dvd_u_677466.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_7_ultimate_with_sp1_x86_dvd_u_677434.iso" ;;
        "he" | "he-"* ) url="he_windows_7_ultimate_with_sp1_x86_dvd_u_677436.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_7_ultimate_with_sp1_x86_dvd_u_677438.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_7_ultimate_with_sp1_x86_dvd_u_677441.iso" ;;
        "it" | "it-"* ) url="it_windows_7_ultimate_with_sp1_x86_dvd_u_677443.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_7_ultimate_with_sp1_x86_dvd_u_677445.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_7_ultimate_k_with_sp1_x86_dvd_u_677508.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_7_ultimate_with_sp1_x86_dvd_u_677447.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_7_ultimate_with_sp1_x86_dvd_u_677449.iso" ;;
        "nb" | "nb-"* ) url="no_windows_7_ultimate_with_sp1_x86_dvd_u_677451.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_7_ultimate_with_sp1_x86_dvd_u_677453.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_7_ultimate_with_sp1_x86_dvd_u_677455.iso" ;;
        "br" | "pt-br" ) url="pt_windows_7_ultimate_with_sp1_x86_dvd_u_677457.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_7_ultimate_with_sp1_x86_dvd_u_677459.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_7_ultimate_with_sp1_x86_dvd_u_677461.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_7_ultimate_with_sp1_x86_dvd_u_677463.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_7_ultimate_with_sp1_x86_dvd_u_677465.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_7_ultimate_with_sp1_x86_dvd_u_677467.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_7_ultimate_with_sp1_x86_dvd_u_677468.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_7_ultimate_with_sp1_x86_dvd_u_677482.iso" ;;
        "th" | "th-"* ) url="th_windows_7_ultimate_with_sp1_x86_dvd_u_677483.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_7_ultimate_with_sp1_x86_dvd_u_677484.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_7_ultimate_with_sp1_x86_dvd_u_677485.iso" ;;
        "zh-hk" ) url="hk_windows_7_ultimate_with_sp1_x86_dvd_u_677487.iso" ;;
        "zh-tw" ) url="tw_windows_7_ultimate_with_sp1_x86_dvd_u_677488.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_7_ultimate_with_sp1_x86_dvd_u_677486.iso" ;;
      esac
      ;;
    "winvistax64" | "winvistax64-enterprise" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_vista_enterprise_with_sp2_x64_dvd_x15-40408.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_vista_enterprise_with_sp2_x64_dvd_x15-40410.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_vista_enterprise_with_sp2_x64_dvd_x15-40412.iso" ;;
        "da" | "da-"* ) url="da_windows_vista_enterprise_with_sp2_x64_dvd_x15-40416.iso" ;;
        "de" | "de-"* ) url="de_windows_vista_enterprise_sp2_x64_dvd_342376.iso" ;;
        "el" | "el-"* ) url="el_windows_vista_enterprise_with_sp2_x64_dvd_x15-40423.iso" ;;
        "en" | "en-"* )
          size=3205953536
          sum="0a0cd511b3eac95c6f081419c9c65b12317b9d6a8d9707f89d646c910e788016"
          url="en_windows_vista_enterprise_sp2_x64_dvd_342332.iso" ;;
        "es" | "es-"* ) url="es_windows_vista_enterprise_sp2_x64_dvd_342415.iso" ;;
        "et" | "et-"* ) url="et_windows_vista_enterprise_with_sp2_x64_dvd_x15-40437.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_vista_enterprise_with_sp2_x64_dvd_x15-40451.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_vista_enterprise_sp2_x64_dvd_342355.iso" ;;
        "he" | "he-"* ) url="he_windows_vista_enterprise_with_sp2_x64_dvd_x15-40425.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_vista_enterprise_with_sp2_x64_dvd_x15-40396.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_vista_enterprise_with_sp2_x64_dvd_x15-40427.iso" ;;
        "it" | "it-"* ) url="it_windows_vista_enterprise_with_sp2_x64_dvd_x15-40429.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_vista_enterprise_sp2_x64_dvd_342393.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_vista_enterprise_k_with_sp2_x64_dvd_x15-40433.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_vista_enterprise_with_sp2_x64_dvd_x15-40394.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_vista_enterprise_with_sp2_x64_dvd_x15-40392.iso" ;;
        "nb" | "nb-"* ) url="no_windows_vista_enterprise_with_sp2_x64_dvd_x15-40439.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_vista_enterprise_with_sp2_x64_dvd_x15-40441.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_vista_enterprise_with_sp2_x64_dvd_x15-40445.iso" ;;
        "br" | "pt-br" ) url="pt_windows_vista_enterprise_with_sp2_x64_dvd_x15-40400.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_vista_enterprise_with_sp2_x64_dvd_x15-40443.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_vista_enterprise_with_sp2_x64_dvd_x15-40447.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_vista_enterprise_with_sp2_x64_dvd_x15-40455.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_vista_enterprise_with_sp2_x64_dvd_x15-40453.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_vista_enterprise_with_sp2_x64_dvd_x15-40435.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_vista_enterprise_with_sp2_x64_dvd_x15-40406.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_vista_enterprise_with_sp2_x64_dvd_x15-40449.iso" ;;
        "th" | "th-"* ) url="th_windows_vista_enterprise_with_sp2_x64_dvd_x15-40457.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_vista_enterprise_with_sp2_x64_dvd_x15-40459.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_vista_enterprise_with_sp2_x64_dvd_x15-40398.iso" ;;
        "zh-hk" ) url="hk_windows_vista_enterprise_with_sp2_x64_dvd_x15-40463.iso" ;;
        "zh-tw" ) url="tw_windows_vista_enterprise_with_sp2_x64_dvd_x15-40461.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_vista_enterprise_with_sp2_x64_dvd_x15-40402.iso" ;;
      esac
      ;;
    "winvistax64-ultimate" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_vista_with_sp2_x64_dvd_x15-36318.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_vista_with_sp2_x64_dvd_x15-36321.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_vista_with_sp2_x64_dvd_x15-36327.iso" ;;
        "da" | "da-"* ) url="da_windows_vista_with_sp2_x64_dvd_x15-36329.iso" ;;
        "de" | "de-"* ) url="de_windows_vista_sp2_x64_dvd_342287.iso" ;;
        "el" | "el-"* ) url="el_windows_vista_with_sp2_x64_dvd_x15-36343.iso" ;;
        "en" | "en-"* )
          size=3861460992
          sum="edf9f947c5791469fd7d2d40a5dcce663efa754f91847aa1d28ed7f585675b78"
          url="en_windows_vista_sp2_x64_dvd_342267.iso" ;;
        "es" | "es-"* ) url="es_windows_vista_sp2_x64_dvd_342309.iso" ;;
        "et" | "et-"* ) url="et_windows_vista_with_sp2_x64_dvd_x15-36335.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_vista_with_sp2_x64_dvd_x15-36337.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_vista_sp2_x64_dvd_342277.iso" ;;
        "he" | "he-"* ) url="he_windows_vista_with_sp2_x64_dvd_x15-36344.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_vista_with_sp2_x64_dvd_x15-36325.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_vista_with_sp2_x64_dvd_x15-36346.iso" ;;
        "it" | "it-"* ) url="it_windows_vista_with_sp2_x64_dvd_x15-36348.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_vista_sp2_x64_dvd_342298.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_vista_k_and_kn_with_sp2_x86_dvd_x15-36302.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_vista_with_sp2_x64_dvd_x15-36355.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_vista_with_sp2_x64_dvd_x15-36353.iso" ;;
        "nb" | "nb-"* ) url="no_windows_vista_with_sp2_x64_dvd_x15-36357.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_vista_with_sp2_x64_dvd_x15-36331.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_vista_with_sp2_x64_dvd_x15-36359.iso" ;;
        "br" | "pt-br" ) url="pt_windows_vista_with_sp2_x64_dvd_x15-36319.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_vista_with_sp2_x64_dvd_x15-36361.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_vista_with_sp2_x64_dvd_x15-36363.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_vista_with_sp2_x64_dvd_x15-36364.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_vista_with_sp2_x64_dvd_x15-36367.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_vista_with_sp2_x64_dvd_x15-36369.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_vista_with_sp2_x64_dvd_x15-36365.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_vista_with_sp2_x64_dvd_x15-36373.iso" ;;
        "th" | "th-"* ) url="th_windows_vista_with_sp2_x64_dvd_x15-36374.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_vista_with_sp2_x64_dvd_x15-36375.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_vista_with_sp2_x64_dvd_x15-36376.iso" ;;
        "zh-hk" ) url="hk_windows_vista_with_sp2_x64_dvd_x15-36324.iso" ;;
        "zh-tw" ) url="tw_windows_vista_with_sp2_x64_dvd_x15-36323.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_vista_with_sp2_x64_dvd_x15-36322.iso" ;;
      esac
      ;;
    "winvistax86" | "winvistax86-enterprise" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_vista_enterprise_with_sp2_x86_dvd_x15-40263.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_vista_enterprise_with_sp2_x86_dvd_x15-40265.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_vista_enterprise_with_sp2_x86_dvd_x15-40267.iso" ;;
        "da" | "da-"* ) url="da_windows_vista_enterprise_with_sp2_x86_dvd_x15-40271.iso" ;;
        "de" | "de-"* ) url="de_windows_vista_enterprise_sp2_x86_dvd_342373.iso" ;;
        "el" | "el-"* ) url="el_windows_vista_enterprise_with_sp2_x86_dvd_x15-40277.iso" ;;
        "en" | "en-"* )
          size=2420981760
          sum="54e2720004041e7db988a391543ea5228b0affc28efcf9303d2d0ff9402067f5"
          url="en_windows_vista_enterprise_sp2_x86_dvd_342329.iso" ;;
        "es" | "es-"* ) url="es_windows_vista_enterprise_sp2_x86_dvd_342413.iso" ;;
        "et" | "et-"* ) url="et_windows_vista_enterprise_with_sp2_x86_dvd_x15-40291.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_vista_enterprise_with_sp2_x86_dvd_x15-40305.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_vista_enterprise_sp2_x86_dvd_342352.iso" ;;
        "he" | "he-"* ) url="he_windows_vista_enterprise_with_sp2_x86_dvd_x15-40279.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_vista_enterprise_with_sp2_x86_dvd_x15-40251.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_vista_enterprise_with_sp2_x86_dvd_x15-40281.iso" ;;
        "it" | "it-"* ) url="it_windows_vista_enterprise_with_sp2_x86_dvd_x15-40283.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_vista_enterprise_sp2_x86_dvd_342391.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_vista_enterprise_k_with_sp2_x86_dvd_x15-40287.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_vista_enterprise_with_sp2_x86_dvd_x15-40249.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_vista_enterprise_with_sp2_x86_dvd_x15-40247.iso" ;;
        "nb" | "nb-"* ) url="no_windows_vista_enterprise_with_sp2_x86_dvd_x15-40293.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_vista_enterprise_with_sp2_x86_dvd_x15-40295.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_vista_enterprise_with_sp2_x86_dvd_x15-40299.iso" ;;
        "br" | "pt-br" ) url="pt_windows_vista_enterprise_with_sp2_x86_dvd_x15-40255.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_vista_enterprise_with_sp2_x86_dvd_x15-40297.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_vista_enterprise_with_sp2_x86_dvd_x15-40301.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_vista_enterprise_with_sp2_x86_dvd_x15-40309.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_vista_enterprise_with_sp2_x86_dvd_x15-40307.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_vista_enterprise_with_sp2_x86_dvd_x15-40289.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_vista_enterprise_with_sp2_x86_dvd_x15-40261.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_vista_enterprise_with_sp2_x86_dvd_x15-40303.iso" ;;
        "th" | "th-"* ) url="th_windows_vista_enterprise_with_sp2_x86_dvd_x15-40311.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_vista_enterprise_with_sp2_x86_dvd_x15-40313.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_vista_enterprise_with_sp2_x86_dvd_x15-40253.iso" ;;
        "zh-hk" ) url="hk_windows_vista_enterprise_with_sp2_x86_dvd_x15-40317.iso" ;;
        "zh-tw" ) url="tw_windows_vista_enterprise_with_sp2_x86_dvd_x15-40315.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_vista_enterprise_with_sp2_x86_dvd_x15-40257.iso" ;;
      esac
      ;;
    "winvistax86-ultimate" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_vista_with_sp2_x86_dvd_x15-36282.iso" ;;
        "bg" | "bg-"* ) url="bg_windows_vista_with_sp2_x86_dvd_x15-36284.iso" ;;
        "hr" | "hr-"* ) url="hr_windows_vista_with_sp2_x86_dvd_x15-36288.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_vista_with_sp2_x86_dvd_x15-36289.iso" ;;
        "da" | "da-"* ) url="da_windows_vista_with_sp2_x86_dvd_x15-36290.iso" ;;
        "de" | "de-"* ) url="de_windows_vista_sp2_x86_dvd_342286.iso" ;;
        "el" | "el-"* ) url="el_windows_vista_with_sp2_x86_dvd_x15-36297.iso" ;;
        "en" | "en-"* )
          size=3243413504
          sum="9c36fed4255bd05a8506b2da88f9aad73643395e155e609398aacd2b5276289c"
          url="en_windows_vista_with_sp2_x86_dvd_342266.iso" ;;
        "es" | "es-"* ) url="es_windows_vista_sp2_x86_dvd_342308.iso" ;;
        "et" | "et-"* ) url="et_windows_vista_with_sp2_x86_dvd_x15-36293.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_vista_with_sp2_x86_dvd_x15-36294.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_vista_sp2_x86_dvd_342276.iso" ;;
        "he" | "he-"* ) url="he_windows_vista_with_sp2_x86_dvd_x15-36298.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_vista_with_sp2_x86_dvd_x15-36299.iso" ;;
        "it" | "it-"* ) url="it_windows_vista_with_sp2_x86_dvd_x15-36300.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_vista_sp2_x86_dvd_342296.iso" ;;
        "ko" | "ko-"* ) url="ko_windows_vista_k_with_sp2_x64_dvd_x15-36350.iso" ;;
        "lt" | "lt-"* ) url="lt_windows_vista_with_sp2_x86_dvd_x15-36304.iso" ;;
        "lv" | "lv-"* ) url="lv_windows_vista_with_sp2_x86_dvd_x15-36303.iso" ;;
        "nb" | "nb-"* ) url="no_windows_vista_with_sp2_x86_dvd_x15-36305.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_vista_with_sp2_x86_dvd_x15-36291.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_vista_with_sp2_x86_dvd_x15-36306.iso" ;;
        "br" | "pt-br" ) url="pt_windows_vista_with_sp2_x86_dvd_x15-36283.iso" ;;
        "pt" | "pt-"* ) url="pp_windows_vista_with_sp2_x86_dvd_x15-36307.iso" ;;
        "ro" | "ro-"* ) url="ro_windows_vista_with_sp2_x86_dvd_x15-36308.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_vista_with_sp2_x86_dvd_x15-36309.iso" ;;
        "sk" | "sk-"* ) url="sk_windows_vista_with_sp2_x86_dvd_x15-36311.iso" ;;
        "sl" | "sl-"* ) url="sl_windows_vista_with_sp2_x86_dvd_x15-36312.iso" ;;
        "sr" | "sr-"* ) url="sr_windows_vista_with_sp2_x86_dvd_x15-36310.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_vista_with_sp2_x86_dvd_x15-36314.iso" ;;
        "th" | "th-"* ) url="th_windows_vista_with_sp2_x86_dvd_x15-36315.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_vista_with_sp2_x86_dvd_x15-36316.iso" ;;
        "uk" | "uk-"* ) url="uk_windows_vista_with_sp2_x86_dvd_x15-36317.iso" ;;
        "zh-hk" ) url="hk_windows_vista_with_sp2_x86_dvd_x15-36287.iso" ;;
        "zh-tw" ) url="tw_windows_vista_with_sp2_x86_dvd_x15-36286.iso" ;;
        "zh" | "zh-"* ) url="cn_windows_vista_with_sp2_x86_dvd_x15-36285.iso" ;;
      esac
      ;;
    "winxpx86" )
      case "${culture,,}" in
        "ar" | "ar-"* ) url="ar_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74065.iso" ;;
        "cs" | "cs-"* ) url="cs_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73965.iso" ;;
        "da" | "da-"* ) url="da_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73968.iso" ;;
        "de" | "de-"* ) url="de_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73985.iso" ;;
        "el" | "el-"* ) url="el_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73988.iso" ;;
        "es" | "es-"* ) url="es_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74009.iso" ;;
        "fi" | "fi-"* ) url="fi_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73979.iso" ;;
        "fr" | "fr-"* ) url="fr_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73982.iso" ;;
        "he" | "he-"* ) url="he_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74143.iso" ;;
        "hu" | "hu-"* ) url="hu_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73991.iso" ;;
        "it" | "it-"* ) url="it_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73994.iso" ;;
        "ja" | "ja-"* ) url="ja_windows_xp_professional_with_service_pack_3_x86_dvd_vl_x14-74058.iso" ;;
        "nb" | "nb-"* ) url="no_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74000.iso" ;;
        "nl" | "nl-"* ) url="nl_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73971.iso" ;;
        "pl" | "pl-"* ) url="pl_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74003.iso" ;;
        "br" | "pt-br" ) url="pt-br_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74137.iso" ;;
        "pt" | "pt-"* ) url="pt-pt_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74006.iso" ;;
        "ru" | "ru-"* ) url="ru_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74146.iso" ;;
        "sv" | "sv-"* ) url="sv_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74012.iso" ;;
        "tr" | "tr-"* ) url="tr_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74085.iso" ;;
        "zh-hk" ) url="zh-hk_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74075.iso" ;;
        "zh-tw" ) url="zh-tw_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74140.iso" ;;
        "zh" | "zh-"* ) url="zh-hans_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-74070.iso" ;;
      esac
      ;;
    "winxpx64" )
      [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0
      size=628168704
      sum="b641514c2265ba6c0a9ddbcfa4a6daaac6539db8d1ce704366cdfe5a516e0495"
      url="en_win_xp_pro_x64_with_sp2_vl_x13-41611.iso"
      ;;
  esac

  case "${ret,,}" in
    "sum" ) echo "$sum" ;;
    "size" ) echo "$size" ;;
    *) [ -n "$url" ] && echo "$host/$url";;
  esac

  return 0
}

getLink4() {

  local id="$1"
  local lang="$2"
  local ret="$3"
  local url=""
  local sum=""
  local size=""
  local host="https://archive.org/download"

  [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-us" ]] && return 0

  case "${id,,}" in
    "core11" )
      size=2159738880
      sum="78f0f44444ff95b97125b43e560a72e0d6ce0a665cf9f5573bf268191e5510c1"
      url="tiny-11-core-x-64-beta-1/tiny11%20core%20x64%20beta%201.iso"
      ;;
    "tiny11" )
      size=3788177408
      sum="a028800a91addc35d8ae22dce7459b67330f7d69d2f11c70f53c0fdffa5b4280"
      url="tiny11-2311/tiny11%202311%20x64.iso"
      ;;
    "tiny10" )
      size=3839819776
      sum="a11116c0645d892d6a5a7c585ecc1fa13aa66f8c7cc6b03bf1f27bd16860cc35"
      url="tiny-10-23-h2/tiny10%20x64%2023h2.iso"
      ;;
    "winxpx86" )
      size=617756672
      sum="62b6c91563bad6cd12a352aa018627c314cfc5162d8e9f8af0756a642e602a46"
      url="XPPRO_SP3_ENU/en_windows_xp_professional_with_service_pack_3_x86_cd_x14-80428.iso"
      ;;
  esac

  case "${ret,,}" in
    "sum" ) echo "$sum" ;;
    "size" ) echo "$size" ;;
    *) [ -n "$url" ] && echo "$host/$url";;
  esac

  return 0
}

getValue() {

  local val=""
  local id="$2"
  local lang="$3"
  local type="$4"
  local func="getLink$1"

  if [ "$1" -gt 0 ] && [ "$1" -le "$MIRRORS" ]; then
    val=$($func "$id" "$lang" "$type")
  fi

  echo "$val"
  return 0
}

getLink() {

  local url
  url=$(getValue "$1" "$2" "$3" "")

  echo "$url"
  return 0
}

getHash() {

  local sum
  sum=$(getValue "$1" "$2" "$3" "sum")

  echo "$sum"
  return 0
}

getSize() {

  local size
  size=$(getValue "$1" "$2" "$3" "size")

  echo "$size"
  return 0
}

isMido() {

  local id="$1"
  local lang="$2"
  local sum

  sum=$(getMido "$id" "en" "sum")
  [ -n "$sum" ] && return 0

  return 1
}

isESD() {

  local id="$1"
  local lang="$2"

  case "${id,,}" in
    "win11${PLATFORM,,}" | "win10${PLATFORM,,}" )
      return 0
      ;;
    "win11${PLATFORM,,}-enterprise" | "win11${PLATFORM,,}-enterprise-eval")
      return 0
      ;;
    "win10${PLATFORM,,}-enterprise" | "win10${PLATFORM,,}-enterprise-eval" )
      return 0
      ;;
  esac

  return 1
}

validVersion() {

  local id="$1"
  local lang="$2"
  local url

  isESD "$id" "$lang" && return 0
  isMido "$id" "$lang" && return 0

  for ((i=1;i<=MIRRORS;i++)); do

    url=$(getLink "$i" "$id" "$lang")
    [ -n "$url" ] && return 0

  done

  return 1
}

migrateFiles() {

  local base="$1"
  local version="$2"
  local file=""

  [ -f "$base" ] && return 0

  [[ "${version,,}" == "tiny10" ]] && file="tiny10_x64_23h2.iso"
  [[ "${version,,}" == "tiny11" ]] && file="tiny11_2311_x64.iso"
  [[ "${version,,}" == "core11" ]] && file="tiny11_core_x64_beta_1.iso"
  [[ "${version,,}" == "winxpx86" ]] && file="en_windows_xp_professional_with_service_pack_3_x86_cd_x14-80428.iso"
  [[ "${version,,}" == "winvistax64" ]] && file="en_windows_vista_sp2_x64_dvd_342267.iso"
  [[ "${version,,}" == "win7x64" ]] && file="en_windows_7_enterprise_with_sp1_x64_dvd_u_677651.iso"

  [ ! -f "$STORAGE/$file" ] && return 0
  ! mv -f "$STORAGE/$file" "$base" && return 1

  return 0
}

prepareInstall() {

  local dir="$2"
  local desc="$3"
  local arch="$4"
  local key="$5"
  local driver="$6"
  local drivers="$TMP/drivers"

  ETFS="[BOOT]/Boot-NoEmul.img"

  if [ ! -f "$dir/$ETFS" ] || [ ! -s "$dir/$ETFS" ]; then
    error "Failed to locate file \"$ETFS\" in $desc ISO image!" && return 1
  fi

  local msg="Adding drivers to image..."

  mkdir -p "$drivers"

  if ! tar -xf /drivers.tar.xz -C "$drivers" --warning=no-timestamp; then
    error "Failed to extract drivers!" && return 1
  fi

  local target
  [[ "${arch,,}" == "x86" ]] && target="$dir/I386" || target="$dir/AMD64"

  cp "$drivers/viostor/$driver/$arch/viostor.sys" "$target"

  mkdir -p "$dir/\$OEM\$/\$1/Drivers/viostor"
  cp "$drivers/viostor/$driver/$arch/viostor.cat" "$dir/\$OEM\$/\$1/Drivers/viostor"
  cp "$drivers/viostor/$driver/$arch/viostor.inf" "$dir/\$OEM\$/\$1/Drivers/viostor"
  cp "$drivers/viostor/$driver/$arch/viostor.sys" "$dir/\$OEM\$/\$1/Drivers/viostor"

  mkdir -p "$dir/\$OEM\$/\$1/Drivers/NetKVM"
  cp "$drivers/NetKVM/$driver/$arch/netkvm.cat" "$dir/\$OEM\$/\$1/Drivers/NetKVM"
  cp "$drivers/NetKVM/$driver/$arch/netkvm.inf" "$dir/\$OEM\$/\$1/Drivers/NetKVM"
  cp "$drivers/NetKVM/$driver/$arch/netkvm.sys" "$dir/\$OEM\$/\$1/Drivers/NetKVM"

  if [ ! -f "$target/TXTSETUP.SIF" ]; then
    error "The file TXTSETUP.SIF could not be found!" && return 1
  fi

  sed -i '/^\[SCSI.Load\]/s/$/\nviostor=viostor.sys,4/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\nviostor.sys=1,,,,,,4_,4,1,,,1,4/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SCSI\]/s/$/\nviostor=\"Red Hat VirtIO SCSI Disk Device\"/' "$target/TXTSETUP.SIF"
  sed -i '/^\[HardwareIdsDatabase\]/s/$/\nPCI\\VEN_1AF4\&DEV_1001\&SUBSYS_00000000=\"viostor\"/' "$target/TXTSETUP.SIF"
  sed -i '/^\[HardwareIdsDatabase\]/s/$/\nPCI\\VEN_1AF4\&DEV_1001\&SUBSYS_00020000=\"viostor\"/' "$target/TXTSETUP.SIF"
  sed -i '/^\[HardwareIdsDatabase\]/s/$/\nPCI\\VEN_1AF4\&DEV_1001\&SUBSYS_00021AF4=\"viostor\"/' "$target/TXTSETUP.SIF"
  sed -i '/^\[HardwareIdsDatabase\]/s/$/\nPCI\\VEN_1AF4\&DEV_1001\&SUBSYS_00000000=\"viostor\"/' "$target/TXTSETUP.SIF"

  mkdir -p "$dir/\$OEM\$/\$1/Drivers/sata"

  cp -a "$drivers/sata/xp/$arch/." "$dir/\$OEM\$/\$1/Drivers/sata"
  cp -a "$drivers/sata/xp/$arch/." "$target"

  sed -i '/^\[SCSI.Load\]/s/$/\niaStor=iaStor.sys,4/' "$target/TXTSETUP.SIF"
  sed -i '/^\[FileFlags\]/s/$/\niaStor.sys = 16/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\niaStor.cat = 1,,,,,,,1,0,0/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\niaStor.inf = 1,,,,,,,1,0,0/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\niaStor.sys = 1,,,,,,4_,4,1,,,1,4/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\niaStor.sys = 1,,,,,,,1,0,0/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\niaahci.cat = 1,,,,,,,1,0,0/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SourceDisksFiles.'"$arch"'\]/s/$/\niaAHCI.inf = 1,,,,,,,1,0,0/' "$target/TXTSETUP.SIF"
  sed -i '/^\[SCSI\]/s/$/\niaStor=\"Intel\(R\) SATA RAID\/AHCI Controller\"/' "$target/TXTSETUP.SIF"
  sed -i '/^\[HardwareIdsDatabase\]/s/$/\nPCI\\VEN_8086\&DEV_2922\&CC_0106=\"iaStor\"/' "$target/TXTSETUP.SIF"

  rm -rf "$drivers"

  local pid file setup
  setup=$(find "$target" -maxdepth 1 -type f -iname setupp.ini | head -n 1)
  pid=$(<"$setup")
  pid="${pid:(-4)}"
  pid="${pid:0:3}"

  if [[ "$pid" == "270" ]]; then
    warn "this version of $desc requires a volume license key (VLK), it will ask for one during installation."
  fi

  local oem=""
  local folder="/oem"

  [ ! -d "$folder" ] && folder="/OEM"
  [ ! -d "$folder" ] && folder="$STORAGE/oem"
  [ ! -d "$folder" ] && folder="$STORAGE/OEM"

  if [ -d "$folder" ]; then

    file=$(find "$folder" -maxdepth 1 -type f -iname install.bat | head -n 1)

    if [ -f "$file" ]; then
      unix2dos -q "$file"
      oem="\"Script\"=\"cmd /C start \\\"Install\\\" \\\"cmd /C C:\\\\OEM\\\\install.bat\\\"\""
    fi
  fi

  [ -z "$YRES" ] && YRES="720"
  [ -z "$XRES" ] && XRES="1280"

  XHEX=$(printf '%x\n' "$XRES")
  YHEX=$(printf '%x\n' "$YRES")

  local username="Docker"
  local password="*"

  [ -n "$PASSWORD" ] && password="$PASSWORD"
  [ -n "$USERNAME" ] && username=$(echo "$USERNAME" | sed 's/[^[:alnum:]@!._-]//g')

  find "$target" -maxdepth 1 -type f -iname winnt.sif -exec rm {} \;

  {       echo "[Data]"
          echo "    AutoPartition=1"
          echo "    MsDosInitiated=\"0\""
          echo "    UnattendedInstall=\"Yes\""
          echo "    AutomaticUpdates=\"Yes\""
          echo ""
          echo "[Unattended]"
          echo "    UnattendSwitch=Yes"
          echo "    UnattendMode=FullUnattended"
          echo "    FileSystem=NTFS"
          echo "    OemSkipEula=Yes"
          echo "    OemPreinstall=Yes"
          echo "    Repartition=Yes"
          echo "    WaitForReboot=\"No\""
          echo "    DriverSigningPolicy=\"Ignore\""
          echo "    NonDriverSigningPolicy=\"Ignore\""
          echo "    OemPnPDriversPath=\"Drivers\viostor;Drivers\NetKVM;Drivers\sata\""
          echo "    NoWaitAfterTextMode=1"
          echo "    NoWaitAfterGUIMode=1"
          echo "    FileSystem-ConvertNTFS"
          echo "    ExtendOemPartition=0"
          echo "    Hibernation=\"No\""
          echo ""
          echo "[GuiUnattended]"
          echo "    OEMSkipRegional=1"
          echo "    OemSkipWelcome=1"
          echo "    AdminPassword=$password"
          echo "    TimeZone=0"
          echo "    AutoLogon=Yes"
          echo "    AutoLogonCount=65432"
          echo ""
          echo "[UserData]"
          echo "    FullName=\"$username\""
          echo "    ComputerName=\"*\""
          echo "    OrgName=\"Windows for Docker\""
          echo "    ProductKey=$key"
          echo ""
          echo "[Identification]"
          echo "    JoinWorkgroup = WORKGROUP"
          echo ""
          echo "[Display]"
          echo "    BitsPerPel=32"
          echo "    XResolution=$XRES"
          echo "    YResolution=$YRES"
          echo ""
          echo "[Networking]"
          echo "    InstallDefaultComponents=Yes"
          echo ""
          echo "[Branding]"
          echo "    BrandIEUsingUnattended=Yes"
          echo ""
          echo "[URL]"
          echo "    Home_Page = http://www.google.com"
          echo "    Search_Page = http://www.google.com"
          echo ""
          echo "[TerminalServices]"
          echo "    AllowConnections=1"
          echo ""
  } | unix2dos > "$target/WINNT.SIF"

  if [[ "$driver" == "2k3" ]]; then
    {       echo "[Components]"
            echo "    TerminalServer=On"
            echo ""
            echo "[LicenseFilePrintData]"
            echo "    AutoMode=PerServer"
            echo "    AutoUsers=5"
            echo ""
    } | unix2dos >> "$target/WINNT.SIF"
  fi

  {       echo "Windows Registry Editor Version 5.00"
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security]"
          echo "\"FirstRunDisabled\"=dword:00000001"
          echo "\"UpdatesDisableNotify\"=dword:00000001"
          echo "\"FirewallDisableNotify\"=dword:00000001"
          echo "\"AntiVirusDisableNotify\"=dword:00000001"
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wscsvc]"
          echo "\"Start\"=dword:00000004"
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile\GloballyOpenPorts\List]"
          echo "\"3389:TCP\"=\"3389:TCP:*:Enabled:@xpsp2res.dll,-22009\""
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa]"
          echo "\"LimitBlankPasswordUse\"=dword:00000000"
          echo ""
          echo "[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Tour]"
          echo "\"RunCount\"=dword:00000000"
          echo ""
          echo "[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]"
          echo "\"HideFileExt\"=dword:00000000"
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon]"
          echo "\"DefaultUserName\"=\"$username\""
          echo "\"DefaultDomainName\"=\"Dockur\""
          echo "\"AltDefaultUserName\"=\"$username\""
          echo "\"AltDefaultDomainName\"=\"Dockur\""
          echo "\"AutoAdminLogon\"=\"1\""
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Video\{23A77BF7-ED96-40EC-AF06-9B1F4867732A}\0000]"
          echo "\"DefaultSettings.BitsPerPel\"=dword:00000020"
          echo "\"DefaultSettings.XResolution\"=dword:00000$XHEX"
          echo "\"DefaultSettings.YResolution\"=dword:00000$YHEX"
          echo ""
          echo "[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Hardware Profiles\Current\System\CurrentControlSet\Control\VIDEO\{23A77BF7-ED96-40EC-AF06-9B1F4867732A}\0000]"
          echo "\"DefaultSettings.BitsPerPel\"=dword:00000020"
          echo "\"DefaultSettings.XResolution\"=dword:00000$XHEX"
          echo "\"DefaultSettings.YResolution\"=dword:00000$YHEX"
          echo ""
          echo "[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce]"
          echo "\"ScreenSaver\"=\"reg add \\\"HKCU\\\\Control Panel\\\\Desktop\\\" /f /v \\\"SCRNSAVE.EXE\\\" /t REG_SZ /d \\\"off\\\"\""
          echo "\"ScreenSaverOff\"=\"reg add \\\"HKCU\\\\Control Panel\\\\Desktop\\\" /f /v \\\"ScreenSaveActive\\\" /t REG_SZ /d \\\"0\\\"\""
          echo "$oem"
          echo ""
  } | unix2dos > "$dir/\$OEM\$/install.reg"

  if [[ "$driver" == "2k3" ]]; then
    {       echo "[HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\srvWiz]"
            echo "@=dword:00000000"
            echo ""
            echo "[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\ServerOOBE\SecurityOOBE]"
            echo "\"DontLaunchSecurityOOBE\"=dword:00000000"
            echo ""
    } | unix2dos >> "$dir/\$OEM\$/install.reg"
  fi

  {       echo "Set WshShell = WScript.CreateObject(\"WScript.Shell\")"
          echo "Set WshNetwork = WScript.CreateObject(\"WScript.Network\")"
          echo "Set Domain = GetObject(\"WinNT://\" & WshNetwork.ComputerName)"
          echo ""
          echo "Function DecodeSID(binSID)"
          echo "  ReDim o(LenB(binSID))"
          echo ""
          echo "  For i = 1 To LenB(binSID)"
          echo "    o(i-1) = AscB(MidB(binSID, i, 1))"
          echo "  Next"
          echo ""
          echo "  sid = \"S-\" & CStr(o(0)) & \"-\" & OctetArrayToString _"
          echo "        (Array(o(2), o(3), o(4), o(5), o(6), o(7)))"
          echo "  For i = 8 To (4 * o(1) + 4) Step 4"
          echo "    sid = sid & \"-\" & OctetArrayToString _"
          echo "          (Array(o(i+3), o(i+2), o(i+1), o(i)))"
          echo "  Next"
          echo ""
          echo "  DecodeSID = sid"
          echo "End Function"
          echo ""
          echo "Function OctetArrayToString(arr)"
          echo "  v = 0"
          echo "  For i = 0 To UBound(arr)"
          echo "    v = v * 256 + arr(i)"
          echo "  Next"
          echo ""
          echo "  OctetArrayToString = CStr(v)"
          echo "End Function"
          echo ""
          echo "For Each DomainItem in Domain"
          echo "  If DomainItem.Class = \"User\" Then"
          echo "    sid = DecodeSID(DomainItem.Get(\"objectSID\"))"
          echo "    If Left(sid, 9) = \"S-1-5-21-\" And Right(sid, 4) = \"-500\" Then"
          echo "      LocalAdminADsPath = DomainItem.ADsPath"
          echo "      Exit For"
          echo "    End If"
          echo "  End If"
          echo "Next"
          echo ""
          echo "Call Domain.MoveHere(LocalAdminADsPath, \"$username\")"
          echo ""
  } | unix2dos > "$dir/\$OEM\$/admin.vbs"

  {       echo "[COMMANDS]"
          echo "\"REGEDIT /s install.reg\""
          echo "\"Wscript admin.vbs\""
          echo ""
  } | unix2dos > "$dir/\$OEM\$/cmdlines.txt"

  [ ! -d "$folder" ] && return 0

  msg="Adding OEM folder to image..."

  local dest="$dir/\$OEM\$/\$1/"
  mkdir -p "$dest"

  if ! cp -r "$folder" "$dest"; then
    error "Failed to copy OEM folder!" && return 1
  fi

  return 0
}

prepare2k3() {

  local iso="$1"
  local dir="$2"
  local desc="$3"
  local driver="2k3"
  local arch key

  [ -d "$dir/AMD64" ] && arch="amd64" || arch="x86"

  if [[ "${arch,,}" == "x86" ]]; then
    # Windows Server 2003 Standard x86 generic key (no activation, trial-only)
    # This is not a pirated key, it comes from the official MS documentation.
    key="QKDCQ-TP2JM-G4MDG-VR6F2-P9C48"
  else
    # Windows Server 2003 Standard x64 generic key (no activation, trial-only)
    # This is not a pirated key, it comes from the official MS documentation.
    key="P4WJG-WK3W7-3HM8W-RWHCK-8JTRY"
  fi

  ! prepareInstall "$iso" "$dir" "$desc" "$arch" "$key" "$driver" && return 1

  return 0
}

prepareXP() {

  local iso="$1"
  local dir="$2"
  local desc="$3"
  local driver="xp"
  local arch key

  [ -d "$dir/AMD64" ] && arch="amd64" || arch="x86"

  if [[ "${arch,,}" == "x86" ]]; then
    # Windows XP Professional x86 generic key (no activation, trial-only)
    # This is not a pirated key, it comes from the official MS documentation.
    key="DR8GV-C8V6J-BYXHG-7PYJR-DB66Y"
  else
    # Windows XP Professional x64 generic key (no activation, trial-only)
    # This is not a pirated key, it comes from the official MS documentation.
    key="B2RBK-7KPT9-4JP6X-QQFWM-PJD6G"
  fi

  ! prepareInstall "$iso" "$dir" "$desc" "$arch" "$key" "$driver" && return 1

  return 0
}

prepareLegacy() {

  local iso="$1"
  local dir="$2"
  local desc="$3"

  ETFS="boot.img"

  [ -f "$dir/$ETFS" ] && [ -s "$dir/$ETFS" ] && return 0
  rm -f "$dir/$ETFS"

  local len offset
  len=$(isoinfo -d -i "$iso" | grep "Nsect " | grep -o "[^ ]*$")
  offset=$(isoinfo -d -i "$iso" | grep "Bootoff " | grep -o "[^ ]*$")

  if ! dd "if=$iso" "of=$dir/$ETFS" bs=2048 "count=$len" "skip=$offset" status=none; then
    error "Failed to extract boot image from $desc ISO!" && return 1
  fi

  [ -f "$dir/$ETFS" ] && [ -s "$dir/$ETFS" ] && return 0

  error "Failed to locate file \"$ETFS\" in $desc ISO image!"
  return 1
}

detectLegacy() {

  local dir="$1"
  local find find2

  find=$(find "$dir" -maxdepth 1 -type d -iname win95 | head -n 1)
  [ -n "$find" ] && DETECTED="win95" && return 0

  find=$(find "$dir" -maxdepth 1 -type d -iname win98 | head -n 1)
  [ -n "$find" ] && DETECTED="win98" && return 0

  find=$(find "$dir" -maxdepth 1 -type d -iname win9x | head -n 1)
  [ -n "$find" ] && DETECTED="win9x" && return 0

  find=$(find "$dir" -maxdepth 1 -type f -iname cdrom_nt.5 | head -n 1)
  [ -n "$find" ] && DETECTED="win2k" && return 0

  find=$(find "$dir" -maxdepth 1 -type d -iname win51 | head -n 1)
  find2=$(find "$dir" -maxdepth 1 -type f -iname setupxp.htm | head -n 1)

  if [ -n "$find" ] || [ -n "$find2" ] || [ -f "$dir/WIN51AP" ] || [ -f "$dir/WIN51IC" ]; then
    [ -d "$dir/AMD64" ] && DETECTED="winxpx64" && return 0
    DETECTED="winxpx86" && return 0
  fi

  if [ -f "$dir/WIN51IA" ] || [ -f "$dir/WIN51IB" ] || [ -f "$dir/WIN51ID" ] || [ -f "$dir/WIN51IL" ] || [ -f "$dir/WIN51IS" ]; then
    DETECTED="win2003r2" && return 0
  fi

  if [ -f "$dir/WIN51AA" ] || [ -f "$dir/WIN51AD" ] || [ -f "$dir/WIN51AS" ] || [ -f "$dir/WIN51MA" ] || [ -f "$dir/WIN51MD" ]; then
    DETECTED="win2003r2" && return 0
  fi

  return 1
}

skipVersion() {

  local id="$1"

  case "${id,,}" in
    "win9"* | "winxp"* | "win2k"* | "win2003"* )
      return 0 ;;
  esac

  return 1
}

setMachine() {

  local id="$1"
  local iso="$2"
  local dir="$3"
  local desc="$4"

  case "${id,,}" in
    "win9"* | "win2k"* )
      MACHINE="pc-i440fx-2.4" ;;
    "winxp"* | "win2003"* | "winvistax86"* | "win7x86"* )
      MACHINE="pc-q35-2.10" ;;
  esac

  case "${id,,}" in
    "win9"* | "win2k"* | "winxp"* | "win2003"* )
      BOOT_MODE="windows_legacy" ;;
    "winvista"* | "win7"* | "win2008"* )
      BOOT_MODE="windows_legacy" ;;
  esac

  case "${id,,}" in
    "win9"* )
      DISK_TYPE="auto"
      ETFS="[BOOT]/Boot-1.44M.img" ;;
    "win2k"* )
      DISK_TYPE="auto"
      ETFS="[BOOT]/Boot-NoEmul.img" ;;
    "winxp"* )
      DISK_TYPE="blk"
      if ! prepareXP "$iso" "$dir" "$desc"; then
        error "Failed to prepare $desc ISO!" && return 1
      fi ;;
    "win2003"* )
      DISK_TYPE="blk"
      if ! prepare2k3 "$iso" "$dir" "$desc"; then
        error "Failed to prepare $desc ISO!" && return 1
      fi ;;
  esac

  return 0
}
    
# Define versions
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
# Download code

handle_curl_error() {

  local error_code="$1"

  case "$error_code" in
    1) error "Unsupported protocol!" ;;
    2) error "Failed to initialize curl!" ;;
    3) error "The URL format is malformed!" ;;
    5) error "Failed to resolve address of proxy host!" ;;
    6) error "Failed to resolve Microsoft servers! Is there an Internet connection?" ;;
    7) error "Failed to contact Microsoft servers! Is there an Internet connection or is the server down?" ;;
    8) error "Microsoft servers returned a malformed HTTP response!" ;;
    16) error "A problem was detected in the HTTP2 framing layer!" ;;
    22) error "Microsoft servers returned a failing HTTP status code!" ;;
    23) error "Failed at writing Windows media to disk! Out of disk space or permission error?" ;;
    26) error "Failed to read Windows media from disk!" ;;
    27) error "Ran out of memory during download!" ;;
    28) error "Connection timed out to Microsoft server!" ;;
    35) error "SSL connection error from Microsoft server!" ;;
    36) error "Failed to continue earlier download!" ;;
    52) error "Received no data from the Microsoft server!" ;;
    63) error "Microsoft servers returned an unexpectedly large response!" ;;
    # POSIX defines exit statuses 1-125 as usable by us
    # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_08_02
    $((error_code <= 125)))
      # Must be some other server or network error (possibly with this specific request/file)
      # This is when accounting for all possible errors in the curl manual assuming a correctly formed curl command and an HTTP(S) request, using only the curl features we're using, and a sane build
      error "Miscellaneous server or network error, reason: $error_code"
      ;;
    126 | 127 ) error "Curl command not found!" ;;
    # Exit statuses are undefined by POSIX beyond this point
    *)
      case "$(kill -l "$error_code")" in
        # Signals defined to exist by POSIX:
        # https://pubs.opengroup.org/onlinepubs/009695399/basedefs/signal.h.html
        INT) error "Curl was interrupted!" ;;
        # There could be other signals but these are most common
        SEGV | ABRT ) error "Curl crashed! Please report any core dumps to curl developers." ;;
        *) error "Curl terminated due to fatal signal $error_code !" ;;
      esac
  esac

  return 1
}

get_agent() {

  local user_agent

  # Determine approximate latest Firefox release
  browser_version="$((124 + ($(date +%s) - 1710892800) / 2419200))"
  echo "Mozilla/5.0 (X11; Linux x86_64; rv:${browser_version}.0) Gecko/20100101 Firefox/${browser_version}.0"

  return 0
}

download_windows() {

  local id="$1"
  local lang="$2"
  local desc="$3"
  local sku_id=""
  local language=""
  local session_id=""
  local user_agent=""
  local windows_version=""
  local iso_download_link=""
  local product_edition_id=""
  local iso_download_link_html=""
  local iso_download_page_html=""
  local language_skuid_table_html=""

  case "${id,,}" in
    "win11x64" ) windows_version="11" ;;
    "win10x64" ) windows_version="10" ;;
    "win81x64" ) windows_version="8" ;;
    * ) error "Invalid VERSION specified, value \"$id\" is not recognized!" && return 1 ;;
  esac

  user_agent=$(get_agent)
  language=$(getLanguage "$lang" "name")

  local url="https://www.microsoft.com/en-us/software-download/windows$windows_version"
  case "$windows_version" in
    8 | 10) url+="ISO";;
  esac

  # uuidgen: For MacOS (installed by default) and other systems (e.g. with no /proc) that don't have a kernel interface for generating random UUIDs
  session_id=$(cat /proc/sys/kernel/random/uuid 2> /dev/null || uuidgen --random)

  # Get product edition ID for latest release of given Windows version
  # Product edition ID: This specifies both the Windows release (e.g. 22H2) and edition ("multi-edition" is default, either Home/Pro/Edu/etc., we select "Pro" in the answer files) in one number
  # This is the *only* request we make that Fido doesn't. Fido manually maintains a list of all the Windows release/edition product edition IDs in its script (see: $WindowsVersions array). This is helpful for downloading older releases (e.g. Windows 10 1909, 21H1, etc.) but we always want to get the newest release which is why we get this value dynamically
  # Also, keeping a "$WindowsVersions" array like Fido does would be way too much of a maintenance burden
  # Remove "Accept" header that curl sends by default
  [[ "$DEBUG" == [Yy1]* ]] && echo " - Parsing download page: ${url}"
  iso_download_page_html=$(curl --silent --max-time 30 --user-agent "$user_agent" --header "Accept:" --max-filesize 1M --fail --proto =https --tlsv1.2 --http1.1 -- "$url") || {
    handle_curl_error $?
    return $?
  }

  [[ "$DEBUG" == [Yy1]* ]] && echo -n "Getting Product edition ID: "
  # tr: Filter for only numerics to prevent HTTP parameter injection
  # head -c was recently added to POSIX: https://austingroupbugs.net/view.php?id=407
  product_edition_id=$(echo "$iso_download_page_html" | grep -Eo '<option value="[0-9]+">Windows' | cut -d '"' -f 2 | head -n 1 | tr -cd '0-9' | head -c 16)
  [[ "$DEBUG" == [Yy1]* ]] && echo "$product_edition_id"

  [[ "$DEBUG" == [Yy1]* ]] && echo "Permit Session ID: $session_id"
  # Permit Session ID
  # "org_id" is always the same value
  curl --silent --max-time 30 --output /dev/null --user-agent "$user_agent" --header "Accept:" --max-filesize 100K --fail --proto =https --tlsv1.2 --http1.1 -- "https://vlscppe.microsoft.com/tags?org_id=y6jn8c31&session_id=$session_id" || {
    # This should only happen if there's been some change to how this API works
    handle_curl_error $?
    return $?
  }

  # Extract everything after the last slash
  local url_segment_parameter="${url##*/}"

  [[ "$DEBUG" == [Yy1]* ]] && echo -n "Getting language SKU ID: "
  # Get language -> skuID association table
  # SKU ID: This specifies the language of the ISO. We always use "English (United States)", however, the SKU for this changes with each Windows release
  # We must make this request so our next one will be allowed
  # --data "" is required otherwise no "Content-Length" header will be sent causing HTTP response "411 Length Required"
  language_skuid_table_html=$(curl --silent --max-time 30 --request POST --user-agent "$user_agent" --data "" --header "Accept:" --max-filesize 10K --fail --proto =https --tlsv1.2 --http1.1 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=a8f8f489-4c7f-463a-9ca6-5cff94d8d041&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=getskuinformationbyproductedition&sessionId=$session_id&productEditionId=$product_edition_id&sdVersion=2") || {
    handle_curl_error $?
    return $?
  }

  # tr: Filter for only alphanumerics or "-" to prevent HTTP parameter injection
  sku_id=$(echo "$language_skuid_table_html" | grep -m 1 ">${language}<" | sed 's/&quot;//g' | cut -d ',' -f 1  | cut -d ':' -f 2 | tr -cd '[:alnum:]-' | head -c 16)

  if [ -z "$sku_id" ]; then
    language=$(getLanguage "$lang" "desc")
    error "No download in the $language language available for $desc!"
    return 1
  fi

  [[ "$DEBUG" == [Yy1]* ]] && echo "$sku_id"
  [[ "$DEBUG" == [Yy1]* ]] && echo "Getting ISO download link..."

  # Get ISO download link
  # If any request is going to be blocked by Microsoft it's always this last one (the previous requests always seem to succeed)
  # --referer: Required by Microsoft servers to allow request
  iso_download_link_html=$(curl --silent --max-time 30 --request POST --user-agent "$user_agent" --data "" --referer "$url" --header "Accept:" --max-filesize 100K --fail --proto =https --tlsv1.2 --http1.1 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=6e2a1789-ef16-4f27-a296-74ef7ef5d96b&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=GetProductDownloadLinksBySku&sessionId=$session_id&skuId=$sku_id&language=English&sdVersion=2")

  if ! [ "$iso_download_link_html" ]; then
    # This should only happen if there's been some change to how this API works
    error "Microsoft servers gave us an empty response to our request for an automated download."
    return 1
  fi

  if echo "$iso_download_link_html" | grep -q "We are unable to complete your request at this time."; then
    error "Microsoft blocked the automated download request based on your IP address."
    return 1
  fi

  # Filter for 64-bit ISO download URL
  # sed: HTML decode "&" character
  # tr: Filter for only alphanumerics or punctuation
  iso_download_link=$(echo "$iso_download_link_html" | grep -o "https://software.download.prss.microsoft.com.*IsoX64" | cut -d '"' -f 1 | sed 's/&amp;/\&/g' | tr -cd '[:alnum:][:punct:]')

  if ! [ "$iso_download_link" ]; then
    # This should only happen if there's been some change to the download endpoint web address
    error "Microsoft servers gave us no download link to our request for an automated download!"
    return 1
  fi

  MIDO_URL="$iso_download_link"
  return 0
}

download_windows_eval() {

  local id="$1"
  local lang="$2"
  local desc="$3"
  local filter=""
  local culture=""
  local language=""
  local user_agent=""
  local enterprise_type=""
  local windows_version=""

  case "${id,,}" in
    "win11${PLATFORM,,}-enterprise-eval" )
      enterprise_type="enterprise"
      windows_version="windows-11-enterprise" ;;
    "win11${PLATFORM,,}-enterprise-iot-eval" )
      enterprise_type="iot"
      windows_version="windows-11-iot-enterprise-ltsc-eval" ;;
    "win11${PLATFORM,,}-enterprise-ltsc-eval" )
      enterprise_type="iot"
      windows_version="windows-11-iot-enterprise-ltsc-eval" ;;
    "win10${PLATFORM,,}-enterprise-eval" )
      enterprise_type="enterprise"
      windows_version="windows-10-enterprise" ;;
    "win10${PLATFORM,,}-enterprise-ltsc-eval" )
      enterprise_type="ltsc"
      windows_version="windows-10-enterprise" ;;
    "win2025-eval" )
      enterprise_type="server"
      windows_version="windows-server-2025" ;;
    "win2022-eval" )
      enterprise_type="server"
      windows_version="windows-server-2022" ;;
    "win2019-eval" )
      enterprise_type="server"
      windows_version="windows-server-2019" ;;
    "win2016-eval" )
      enterprise_type="server"
      windows_version="windows-server-2016" ;;
    "win2012r2-eval" )
      enterprise_type="server"
      windows_version="windows-server-2012-r2" ;;
    * )
      error "Invalid VERSION specified, value \"$id\" is not recognized!" && return 1 ;;
  esac

  user_agent=$(get_agent)
  culture=$(getLanguage "$lang" "culture")

  local country="${culture#*-}"
  local iso_download_page_html=""
  local url="https://www.microsoft.com/en-us/evalcenter/download-$windows_version"

  [[ "$DEBUG" == [Yy1]* ]] && echo "Parsing download page: ${url}"
  iso_download_page_html=$(curl --silent --max-time 30 --user-agent "$user_agent" --location --max-filesize 1M --fail --proto =https --tlsv1.2 --http1.1 -- "$url") || {
    handle_curl_error $?
    return $?
  }

  if ! [ "$iso_download_page_html" ]; then
    # This should only happen if there's been some change to where this download page is located
    error "Windows server download page gave us an empty response"
    return 1
  fi

  [[ "$DEBUG" == [Yy1]* ]] && echo "Getting download link.."

  if [[ "$enterprise_type" == "iot" ]]; then
    filter="https://go.microsoft.com/fwlink/?linkid=[0-9]\+&clcid=0x[0-9a-z]\+&culture=${culture,,}&country=${country^^}"
  else
    filter="https://go.microsoft.com/fwlink/p/?LinkID=[0-9]\+&clcid=0x[0-9a-z]\+&culture=${culture,,}&country=${country^^}"
  fi

  iso_download_links=$(echo "$iso_download_page_html" | grep -io "$filter") || {
    # This should only happen if there's been some change to the download endpoint web address
    if [[ "${lang,,}" == "en" ]] || [[ "${lang,,}" == "en-"* ]]; then
      error "Windows server download page gave us no download link!"
    else
      language=$(getLanguage "$lang" "desc")
      error "No download in the $language language available for $desc!"
    fi
    return 1
  }

  case "$enterprise_type" in
    "enterprise" )
      iso_download_link=$(echo "$iso_download_links" | head -n 2 | tail -n 1)
      ;;
    "iot" )
      if [[ "${PLATFORM,,}" == "x64" ]]; then
        iso_download_link=$(echo "$iso_download_links" | head -n 1)
      fi
      if [[ "${PLATFORM,,}" == "arm64" ]]; then
        iso_download_link=$(echo "$iso_download_links" | head -n 2 | tail -n 1)
      fi
      ;;
    "ltsc" )
      iso_download_link=$(echo "$iso_download_links" | head -n 4 | tail -n 1)
      ;;
    "server" )
      iso_download_link=$(echo "$iso_download_links" | head -n 1)
      ;;
    * )
      error "Invalid type specified, value \"$enterprise_type\" is not recognized!" && return 1 ;;
  esac

  [[ "$DEBUG" == [Yy1]* ]] && echo "Found download link: $iso_download_link"

  # Follow redirect so proceeding log message is useful
  # This is a request we make this Fido doesn't
  # We don't need to set "--max-filesize" here because this is a HEAD request and the output is to /dev/null anyway
  iso_download_link=$(curl --silent --max-time 30 --user-agent "$user_agent" --location --output /dev/null --silent --write-out "%{url_effective}" --head --fail --proto =https --tlsv1.2 --http1.1 -- "$iso_download_link") || {
    # This should only happen if the Microsoft servers are down
    handle_curl_error $?
    return $?
  }

  MIDO_URL="$iso_download_link"
  return 0
}

getWindows() {

  local version="$1"
  local lang="$2"
  local desc="$3"

  local language edition
  language=$(getLanguage "$lang" "desc")
  edition=$(printEdition "$version" "$desc")

  local msg="Requesting $desc from Microsoft server..."
  info "$msg"

  case "${version,,}" in
    "win2008r2" | "win81${PLATFORM,,}-enterprise-eval" | "win11${PLATFORM,,}-enterprise-iot-eval" )
      if [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-"* ]]; then
        error "No download in the $language language available for $edition!"
        MIDO_URL="" && return 1
      fi ;;
  esac

  case "${version,,}" in
    "win11${PLATFORM,,}-enterprise-iot-eval" ) ;;
    * )
      if [[ "${PLATFORM,,}" != "x64" ]]; then
        error "No download for the ${PLATFORM^^} platform available for $edition!"
        MIDO_URL="" && return 1
      fi ;;
  esac

  case "${version,,}" in
    "win81${PLATFORM,,}" | "win10${PLATFORM,,}" | "win11${PLATFORM,,}" )
      download_windows "$version" "$lang" "$edition" && return 0
      ;;
    "win11${PLATFORM,,}-enterprise"* | "win10${PLATFORM,,}-enterprise"* )
      download_windows_eval "$version" "$lang" "$edition" && return 0
      ;;
    "win2025-eval" | "win2022-eval" | "win2019-eval" | "win2016-eval" | "win2012r2-eval" )
      download_windows_eval "$version" "$lang" "$edition" && return 0
      ;;
    "win81${PLATFORM,,}-enterprise-eval" )
      MIDO_URL="https://download.microsoft.com/download/B/9/9/B999286E-0A47-406D-8B3D-5B5AD7373A4A/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_ENTERPRISE_EVAL_EN-US-IR3_CENA_X64FREE_EN-US_DV9.ISO" && return 0
      ;;
    "win2008r2" )
      MIDO_URL="https://download.microsoft.com/download/4/1/D/41DEA7E0-B30D-4012-A1E3-F24DC03BA1BB/7601.17514.101119-1850_x64fre_server_eval_en-us-GRMSXEVAL_EN_DVD.iso" && return 0
      ;;
    * ) error "Invalid VERSION specified, value \"$version\" is not recognized!" ;;
  esac

  MIDO_URL=""
  return 1
}

getCatalog() {

  local id="$1"
  local ret="$2"
  local url=""
  local name=""
  local edition=""

  case "${id,,}" in
    "win11${PLATFORM,,}" )
      edition="Professional"
      name="Windows 11 Pro"
      url="https://go.microsoft.com/fwlink?linkid=2156292" ;;
    "win10${PLATFORM,,}" )
      edition="Professional"
      name="Windows 10 Pro"
      url="https://go.microsoft.com/fwlink/?LinkId=841361" ;;
    "win11${PLATFORM,,}-enterprise" | "win11${PLATFORM,,}-enterprise-eval")
      edition="Enterprise"
      name="Windows 11 Enterprise"
      url="https://go.microsoft.com/fwlink?linkid=2156292" ;;
    "win10${PLATFORM,,}-enterprise" | "win10${PLATFORM,,}-enterprise-eval" )
      edition="Enterprise"
      name="Windows 10 Enterprise"
      url="https://go.microsoft.com/fwlink/?LinkId=841361" ;;
  esac

  case "${ret,,}" in
    "url" ) echo "$url" ;;
    "name" ) echo "$name" ;;
    "edition" ) echo "$edition" ;;
    *) echo "";;
  esac

  return 0
}

getESD() {

  local dir="$1"
  local version="$2"
  local lang="$3"
  local desc="$4"
  local culture
  local language
  local editionName
  local winCatalog size

  culture=$(getLanguage "$lang" "culture")
  winCatalog=$(getCatalog "$version" "url")
  editionName=$(getCatalog "$version" "edition")

  if [ -z "$winCatalog" ] || [ -z "$editionName" ]; then
    error "Invalid VERSION specified, value \"$version\" is not recognized!" && return 1
  fi

  local msg="Downloading product information from Microsoft server..."
  info "$msg"

  rm -rf "$dir"
  mkdir -p "$dir"

  local wFile="catalog.cab"
  local xFile="products.xml"
  local eFile="esd_edition.xml"
  local fFile="products_filter.xml"

  { wget "$winCatalog" -O "$dir/$wFile" -q --timeout=30; rc=$?; } || :

  msg="Failed to download $winCatalog"
  (( rc == 3 )) && error "$msg , cannot write file (disk full?)" && return 1
  (( rc == 4 )) && error "$msg , network failure!" && return 1
  (( rc == 8 )) && error "$msg , server issued an error response!" && return 1
  (( rc != 0 )) && error "$msg , reason: $rc" && return 1

  cd "$dir"

  if ! cabextract "$wFile" > /dev/null; then
    cd /run
    error "Failed to extract $wFile!" && return 1
  fi

  cd /run

  if [ ! -s "$dir/$xFile" ]; then
    error "Failed to find $xFile in $wFile!" && return 1
  fi

  local edQuery='//File[Architecture="'${PLATFORM}'"][Edition="'${editionName}'"]'

  echo -e '<Catalog>' > "$dir/$fFile"
  xmllint --nonet --xpath "${edQuery}" "$dir/$xFile" >> "$dir/$fFile" 2>/dev/null
  echo -e '</Catalog>'>> "$dir/$fFile"

  xmllint --nonet --xpath "//File[LanguageCode=\"${culture,,}\"]" "$dir/$fFile" >"$dir/$eFile"

  size=$(stat -c%s "$dir/$eFile")
  if ((size<20)); then
    desc=$(printEdition "$version" "$desc")
    language=$(getLanguage "$lang" "desc")
    error "No download in the $language language available for $desc!" && return 1
  fi

  local tag="FilePath"
  ESD=$(xmllint --nonet --xpath "//$tag" "$dir/$eFile" | sed -E -e "s/<[\/]?$tag>//g")

  if [ -z "$ESD" ]; then
    error "Failed to find ESD URL in $eFile!" && return 1
  fi

  tag="Sha1"
  ESD_SUM=$(xmllint --nonet --xpath "//$tag" "$dir/$eFile" | sed -E -e "s/<[\/]?$tag>//g")
  tag="Size"
  ESD_SIZE=$(xmllint --nonet --xpath "//$tag" "$dir/$eFile" | sed -E -e "s/<[\/]?$tag>//g")

  rm -rf "$dir"
  return 0
}

verifyFile() {

  local iso="$1"
  local size="$2"
  local total="$3"
  local check="$4"

  local hash=""
  local algo="SHA256"

  [ -z "$check" ] && return 0
  [[ "$VERIFY" != [Yy1]* ]] && return 0
  [[ "${#check}" == "40" ]] && algo="SHA1"

  local msg="Verifying downloaded ISO..."
  info "$msg"

  if [[ "${algo,,}" != "sha256" ]]; then
    hash=$(sha1sum "$iso" | cut -f1 -d' ')
  else
    hash=$(sha256sum "$iso" | cut -f1 -d' ')
  fi

  if [[ "$hash" == "$check" ]]; then
    info "Succesfully verified ISO!" && return 0
  fi

  return 1
}

progress_it(){
	escape () {
    	local s
    	s=${1//&/\&amp;}
    	s=${s//</\&lt;}
    	s=${s//>/\&gt;}
    	s=${s//'"'/\&quot;}
    	printf -- %s "$s"
    	return 0
	}
	
	file="$1"
	total="$2"
	body=$(escape "$3")
	info="/run/shm/msg.html"
	
	if [[ "$body" == *"..." ]]; then
  	body="<p class=\"loading\">${body/.../}</p>"
	fi
	
	while true
	do
  	if [ -s "$file" ]; then
    	bytes=$(du -sb "$file" | cut -f1)
    	if (( bytes > 1000 )); then
      	if [ -z "$total" ] || [[ "$total" == "0" ]]; then
        	size=$(numfmt --to=iec --suffix=B  "$bytes" | sed -r 's/([A-Z])/ \1/')
      	else
        	size="$(echo "$bytes" "$total" | awk '{printf "%.1f", $1 * 100 / $2}')"
        	size="$size%"
      	fi
      	echo "${body//(\[P\])/($size)}"> "$info"
    	fi
  	fi
  	sleep 1 & wait $!
	done
}

downloadFile() {

  local iso="$1"
  local url="$2"
  local sum="$3"
  local size="$4"
  local lang="$5"
  local desc="$6"
  local rc total progress domain dots space folder

  rm -f "$iso"

  if [ -n "$size" ] && [[ "$size" != "0" ]]; then
    folder=$(dirname -- "$iso")
    space=$(df --output=avail -B 1 "$folder" | tail -n 1)
    (( size > space )) && error "Not enough free space left to download file!" && return 1
  fi

  # Check if running with interactive TTY or redirected to docker log
  if [ -t 1 ]; then
    progress="--progress=bar:noscroll"
  else
    progress="--progress=dot:giga"
  fi

  local msg="Downloading $desc"

  domain=$(echo "$url" | awk -F/ '{print $3}')
  dots=$(echo "$domain" | tr -cd '.' | wc -c)
  (( dots > 1 )) && domain=$(expr "$domain" : '.*\.\(.*\..*\)')

  if [ -n "$domain" ] && [[ "${domain,,}" != *"microsoft.com" ]]; then
    msg="Downloading $desc from $domain"
  fi

  info "$msg..."
  progress_it "$iso" "$size" "$msg ([P])..." &

  { wget "$url" -O "$iso" -q --timeout=30 --show-progress "$progress"; rc=$?; } || :

  if (( rc == 0 )) && [ -f "$iso" ]; then
    total=$(stat -c%s "$iso")
    if [ "$total" -lt 100000000 ]; then
      error "Invalid download link: $url (is only $total bytes?). Please report this issue." && return 1
    fi
    ! verifyFile "$iso" "$size" "$total" "$sum" && return 1
    return 0
  fi

  msg="Failed to download $url"
  (( rc == 3 )) && error "$msg , cannot write file (disk full?)" && return 1
  (( rc == 4 )) && error "$msg , network failure!" && return 1
  (( rc == 8 )) && error "$msg , server issued an error response!" && return 1

  error "$msg , reason: $rc"
  return 1
}

downloadImage() {

  local iso="$1"
  local version="$2"
  local lang="$3"
  local tried="n"
  local url sum size base desc language

  if [[ "${version,,}" == "http"* ]]; then
    base=$(basename "$iso")
    desc=$(fromFile "$base")
    downloadFile "$iso" "$version" "" "" "" "$desc" && return 0
    rm -f "$iso"
    return 1
  fi

  if ! validVersion "$version" "en"; then
    error "Invalid VERSION specified, value \"$version\" is not recognized!" && return 1
  fi

  desc=$(printVersion "$version" "")

  if [[ "${lang,,}" != "en" ]] && [[ "${lang,,}" != "en-"* ]]; then
    language=$(getLanguage "$lang" "desc")
    if ! validVersion "$version" "$lang"; then
      desc=$(printEdition "$version" "$desc")
      error "The $language language version of $desc is not available, please switch to English." && return 1
    fi
    desc+=" in $language"
  fi

  if isMido "$version" "$lang"; then
    tried="y"
    if getWindows "$version" "$lang" "$desc"; then
      size=$(getMido "$version" "$lang" "size" )
      sum=$(getMido "$version" "$lang" "sum")
      downloadFile "$iso" "$MIDO_URL" "$sum" "$size" "$lang" "$desc" && return 0
      rm -f "$iso"
    fi
  fi

  switchEdition "$version"

  if isESD "$version" "$lang"; then

    if [[ "$tried" != "n" ]]; then
      info "Failed to download $desc, will try a diferent method now..."
    fi

    tried="y"

    if getESD "$TMP/esd" "$version" "$lang" "$desc"; then
      ISO="${ISO%.*}.esd"
      downloadFile "$ISO" "$ESD" "$ESD_SUM" "$ESD_SIZE" "$lang" "$desc" && return 0
      rm -f "$ISO"
      ISO="$iso"
    fi

  fi

  for ((i=1;i<=MIRRORS;i++)); do

    url=$(getLink "$i" "$version" "$lang")

    if [ -n "$url" ]; then
      if [[ "$tried" != "n" ]]; then
        info "Failed to download $desc, will try another mirror now..."
      fi
      tried="y"
      size=$(getSize "$i" "$version" "$lang")
      sum=$(getHash "$i" "$version" "$lang")
      downloadFile "$iso" "$url" "$sum" "$size" "$lang" "$desc" && return 0
      rm -f "$iso"
    fi

  done

  return 1
}
     
# Download code
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
##################################################################################################################################################################################################################
# Run installation
TMP="$STORAGE/tmp"
DIR="$TMP/unpack"
FB="falling back to manual installation!"
ETFS="boot/etfsboot.com"
EFISYS="efi/microsoft/boot/efisys_noprompt.bin"

skipInstall() {

  local iso="$1"
  local magic byte
  local boot="$STORAGE/windows.boot"
  local previous="$STORAGE/windows.base"

  if [ -f "$previous" ]; then
    previous=$(<"$previous")
    if [ -n "$previous" ]; then
      previous="$STORAGE/$previous"
      if [[ "${previous,,}" != "${iso,,}" ]]; then
        if [ -f "$boot" ] && hasDisk; then
          info "Detected that the version was changed, but ignoring this because Windows is already installed."
          info "Please start with an empty /storage folder, if you want to install a different version of Windows."
          return 0
        fi
        [ -f "$previous" ] && rm -f "$previous"
        return 1
      fi
    fi
  fi

  [ -f "$boot" ] && hasDisk && return 0

  [ ! -f "$iso" ] && return 1
  [ ! -s "$iso" ] && return 1

  # Check if the ISO was already processed by our script
  magic=$(dd if="$iso" seek=0 bs=1 count=1 status=none | tr -d '\000')
  magic="$(printf '%s' "$magic" | od -A n -t x1 -v | tr -d ' \n')"
  byte="16" && [[ "$MANUAL" == [Yy1]* ]] && byte="17"

  if [[ "$magic" != "$byte" ]]; then
    info "The ISO will be processed again because the configuration was changed..."
    return 1
  fi

  return 0
}

startInstall() {

  if [ -z "$CUSTOM" ]; then

    local file="${VERSION//\//}.iso"

    if [[ "${VERSION,,}" == "http"* ]]; then

      file=$(basename "${VERSION%%\?*}")
      : "${file//+/ }"; printf -v file '%b' "${_//%/\\x}"
      file=$(echo "$file" | sed -e 's/[^A-Za-z0-9._-]/_/g')

    else

      local language
      language=$(getLanguage "$LANGUAGE" "culture")
      language="${language%%-*}"

      if [ -n "$language" ] && [[ "${language,,}" != "en" ]]; then
        file="${VERSION//\//}_${language,,}.iso"
      fi

    fi

    BOOT="$STORAGE/$file"

    ! migrateFiles "$BOOT" "$VERSION" && error "Migration failed!" && exit 57

  fi

  skipInstall "$BOOT" && return 1

  rm -rf "$TMP"
  mkdir -p "$TMP"

  if [ -z "$CUSTOM" ]; then

    ISO=$(basename "$BOOT")
    ISO="$TMP/$ISO"

    if [ -f "$BOOT" ] && [ -s "$BOOT" ]; then
      mv -f "$BOOT" "$ISO"
    fi

  fi

  rm -f "$BOOT"
  return 0
}

finishInstall() {

  local iso="$1"
  local aborted="$2"
  local base byte

  if [ ! -s "$iso" ] || [ ! -f "$iso" ]; then
    error "Failed to find ISO file: $iso" && return 1
  fi

  if [[ "$aborted" != [Yy1]* ]]; then
    # Mark ISO as prepared via magic byte
    byte="16" && [[ "$MANUAL" == [Yy1]* ]] && byte="17"
    if ! printf '%b' "\x$byte" | dd of="$iso" bs=1 seek=0 count=1 conv=notrunc status=none; then
      warn "failed to set magic byte in ISO file: $iso"
    fi
  fi

  rm -f "$STORAGE/windows.old"
  rm -f "$STORAGE/windows.vga"
  rm -f "$STORAGE/windows.base"
  rm -f "$STORAGE/windows.boot"
  rm -f "$STORAGE/windows.mode"
  rm -f "$STORAGE/windows.type"

  echo "$file_version" | tee "$STORAGE/windows.ver" > /dev/null 2>&1

  if [[ "$iso" == "$STORAGE/"* ]]; then
    if [[ "$aborted" != [Yy1]* ]] || [ -z "$CUSTOM" ]; then
      base=$(basename "$iso")
      echo "$base" > "$STORAGE/windows.base"
    fi
  fi

  if [[ "${PLATFORM,,}" == "x64" ]]; then
    if [[ "${BOOT_MODE,,}" == "windows_legacy" ]]; then
      echo "$BOOT_MODE" > "$STORAGE/windows.mode"
      if [[ "${MACHINE,,}" != "q35" ]]; then
        echo "$MACHINE" > "$STORAGE/windows.old"
      fi
    else
      # Enable secure boot + TPM on manual installs as Win11 requires
      if [[ "$MANUAL" == [Yy1]* ]] || [[ "$aborted" == [Yy1]* ]]; then
        if [[ "${DETECTED,,}" == "win11"* ]]; then
          BOOT_MODE="windows_secure"
          echo "$BOOT_MODE" > "$STORAGE/windows.mode"
        fi
      fi
      # Enable secure boot on multi-socket systems to workaround freeze
      if [ -n "$SOCKETS" ] && [[ "$SOCKETS" != "1" ]]; then
        BOOT_MODE="windows_secure"
        echo "$BOOT_MODE" > "$STORAGE/windows.mode"
      fi
    fi
  fi

  if [ -n "${VGA:-}" ] && [[ "${VGA:-}" != "virtio" ]] && [[ "${VGA:-}" != "ramfb" ]]; then
    echo "$VGA" > "$STORAGE/windows.vga"
  fi

  if [ -n "${DISK_TYPE:-}" ] && [[ "${DISK_TYPE:-}" != "scsi" ]]; then
    echo "$DISK_TYPE" > "$STORAGE/windows.type"
  fi

  rm -rf "$TMP"
  return 0
}

abortInstall() {

  local dir="$1"
  local iso="$2"
  local efi

  [[ "${iso,,}" == *".esd" ]] && exit 60

  efi=$(find "$dir" -maxdepth 1 -type d -iname efi | head -n 1)

  if [ -z "$efi" ]; then
    [[ "${PLATFORM,,}" == "x64" ]] && BOOT_MODE="windows_legacy"
  fi

  if [ -n "$CUSTOM" ]; then
    BOOT="$iso"
    REMOVE="N"
  else
    if [[ "$iso" != "$BOOT" ]]; then
      if ! mv -f "$iso" "$BOOT"; then
        error "Failed to move ISO file: $iso" && return 1
      fi
    fi
  fi

  finishInstall "$BOOT" "Y" && return 0
  return 1
}

detectCustom() {

  local file base
  CUSTOM=""

  file=$(find / -maxdepth 1 -type f -iname custom.iso | head -n 1)
  [ ! -s "$file" ] && file=$(find "$STORAGE" -maxdepth 1 -type f -iname custom.iso | head -n 1)

  if [ ! -s "$file" ] && [[ "${VERSION,,}" != "http"* ]]; then
    base=$(basename "$VERSION")
    file="$STORAGE/$base"
  fi

  if [ ! -f "$file" ] || [ ! -s "$file" ]; then
    return 0
  fi

  local size
  size="$(stat -c%s "$file")"
  [ -z "$size" ] || [[ "$size" == "0" ]] && return 0

  ISO="$file"
  CUSTOM="$ISO"
  BOOT="$STORAGE/windows.$size.iso"

  return 0
}

extractESD() {

  local iso="$1"
  local dir="$2"
  local version="$3"
  local desc="$4"
  local size size_gb space space_gb desc

  local msg="Extracting $desc bootdisk..."
  info "$msg"

  if [ "$(stat -c%s "$iso")" -lt 100000000 ]; then
    error "Invalid ESD file: Size is smaller than 100 MB" && return 1
  fi

  rm -rf "$dir"
  mkdir -p "$dir"

  size=16106127360
  size_gb=$(( (size + 1073741823)/1073741824 ))
  space=$(df --output=avail -B 1 "$dir" | tail -n 1)
  space_gb=$(( (space + 1073741823)/1073741824 ))

  if (( size > space )); then
    error "Not enough free space in $STORAGE, have $space_gb GB available but need at least $size_gb GB." && return 1
  fi

  local esdImageCount
  esdImageCount=$(wimlib-imagex info "$iso" | awk '/Image Count:/ {print $3}')

  wimlib-imagex apply "$iso" 1 "$dir" --quiet 2>/dev/null || {
    retVal=$?
    error "Extracting $desc bootdisk failed" && return $retVal
  }

  local bootWimFile="$dir/sources/boot.wim"
  local installWimFile="$dir/sources/install.wim"

  local msg="Extracting $desc environment..."
  info "$msg"

  wimlib-imagex export "$iso" 2 "$bootWimFile" --compress=none --quiet || {
    retVal=$?
    error "Adding WinPE failed" && return ${retVal}
  }

  local msg="Extracting $desc setup..."
  info "$msg"

  wimlib-imagex export "$iso" 3 "$bootWimFile" --compress=none --boot --quiet || {
   retVal=$?
   error "Adding Windows Setup failed" && return ${retVal}
  }

  if [[ "${PLATFORM,,}" == "x64" ]]; then
    LABEL="CCCOMA_X64FRE_EN-US_DV9"
  else
    LABEL="CPBA_A64FRE_EN-US_DV9"
  fi

  local msg="Extracting $desc image..."
  info "$msg"

  local edition imageIndex imageEdition
  edition=$(getCatalog "$version" "name")

  if [ -z "$edition" ]; then
    error "Invalid VERSION specified, value \"$version\" is not recognized!" && return 1
  fi

  for (( imageIndex=4; imageIndex<=esdImageCount; imageIndex++ )); do
    imageEdition=$(wimlib-imagex info "$iso" ${imageIndex} | grep '^Description:' | sed 's/Description:[ \t]*//')
    [[ "${imageEdition,,}" != "${edition,,}" ]] && continue
    wimlib-imagex export "$iso" ${imageIndex} "$installWimFile" --compress=LZMS --chunk-size 128K --quiet || {
      retVal=$?
      error "Addition of $imageIndex to the $desc image failed" && return $retVal
    }
    return 0
  done

  error "Failed to find product '$edition' in install.wim!" && return 1
}

extractImage() {

  local iso="$1"
  local dir="$2"
  local version="$3"
  local desc="local ISO"
  local size size_gb space space_gb

  if [ -z "$CUSTOM" ]; then
    desc="downloaded ISO"
    if [[ "$version" != "http"* ]]; then
      desc=$(printVersion "$version" "$desc")
    fi
  fi

  if [[ "${iso,,}" == *".esd" ]]; then
    extractESD "$iso" "$dir" "$version" "$desc" && return 0
    return 1
  fi

  local msg="Extracting $desc image..."
  info "$msg"

  rm -rf "$dir"
  mkdir -p "$dir"

  size=$(stat -c%s "$iso")
  size_gb=$(( (size + 1073741823)/1073741824 ))
  space=$(df --output=avail -B 1 "$dir" | tail -n 1)
  space_gb=$(( (space + 1073741823)/1073741824 ))

  if ((size<100000000)); then
    error "Invalid ISO file: Size is smaller than 100 MB" && return 1
  fi

  if (( size > space )); then
    error "Not enough free space in $STORAGE, have $space_gb GB available but need at least $size_gb GB." && return 1
  fi

  rm -rf "$dir"

  if ! 7z x "$iso" -o"$dir" > /dev/null; then
    error "Failed to extract ISO file: $iso" && return 1
  fi

  LABEL=$(isoinfo -d -i "$iso" | sed -n 's/Volume id: //p')

  return 0
}

getPlatform() {

  local xml="$1"
  local tag="ARCH"
  local platform="x64"
  local arch

  arch=$(sed -n "/$tag/{s/.*<$tag>\(.*\)<\/$tag>.*/\1/;p}" <<< "$xml")

  case "${arch,,}" in
    "0" ) platform="x86" ;;
    "9" ) platform="x64" ;;
    "12" )platform="arm64" ;;
  esac

  echo "$platform"
  return 0
}

checkPlatform() {

  local xml="$1"
  local platform compat

  platform=$(getPlatform "$xml")

  case "${platform,,}" in
    "x86" ) compat="x64" ;;
    "x64" ) compat="$platform" ;;
    "arm64" ) compat="$platform" ;;
    * ) compat="${PLATFORM,,}" ;;
  esac

  [[ "${compat,,}" == "${PLATFORM,,}" ]] && return 0

  error "You cannot boot ${platform^^} images on a $PLATFORM CPU!"
  return 1
}

hasVersion() {

  local id="$1"
  local tag="$2"
  local xml="$3"
  local edition

  [ ! -f "${SCRIPTPATH}/assets/$id.xml" ] && return 1

  edition=$(printEdition "$id" "")
  [ -z "$edition" ] && return 1
  [[ "${xml,,}" != *"<${tag,,}>${edition,,}</${tag,,}>"* ]] && return 1

  return 0
}

selectVersion() {

  local tag="$1"
  local xml="$2"
  local platform="$3"
  local id name prefer

  name=$(sed -n "/$tag/{s/.*<$tag>\(.*\)<\/$tag>.*/\1/;p}" <<< "$xml")
  [[ "$name" == *"Operating System"* ]] && name=""
  [ -z "$name" ] && return 0

  id=$(fromName "$name" "$platform")
  [ -z "$id" ] && warn "Unknown ${tag,,}: '$name'" && return 0

  prefer="$id-enterprise"
  hasVersion "$prefer" "$tag" "$xml" && echo "$prefer" && return 0

  prefer="$id-ultimate"
  hasVersion "$prefer" "$tag" "$xml" && echo "$prefer" && return 0

  prefer="$id"
  hasVersion "$prefer" "$tag" "$xml" && echo "$prefer" && return 0

  prefer=$(getVersion "$name" "$platform")

  echo "$prefer"
  return 0
}

detectVersion() {

  local xml="$1"
  local id platform

  platform=$(getPlatform "$xml")
  id=$(selectVersion "DISPLAYNAME" "$xml" "$platform")
  [ -z "$id" ] && id=$(selectVersion "PRODUCTNAME" "$xml" "$platform")
  [ -z "$id" ] && id=$(selectVersion "NAME" "$xml" "$platform")

  echo "$id"
  return 0
}

detectLanguage() {

  local xml="$1"
  local lang=""

  if [[ "$xml" == *"LANGUAGE><DEFAULT>"* ]]; then
    lang="${xml#*LANGUAGE><DEFAULT>}"
    lang="${lang%%<*}"
  else
    if [[ "$xml" == *"FALLBACK><DEFAULT>"* ]]; then
      lang="${xml#*FALLBACK><DEFAULT>}"
      lang="${lang%%<*}"
    fi
  fi

  if [ -z "$lang" ]; then
   warn "Language could not be detected from ISO!" && return 0
  fi

  local culture
  culture=$(getLanguage "$lang" "culture")
  [ -n "$culture" ] && LANGUAGE="$lang" && return 0

  warn "Invalid language detected: \"$lang\""
  return 0
}

setXML() {

  local file="/custom.xml"

  [ ! -f "$file" ] || [ ! -s "$file" ] && file="$STORAGE/custom.xml"
  [ ! -f "$file" ] || [ ! -s "$file" ] && file="${SCRIPTPATH}/assets/custom.xml"
  [ ! -f "$file" ] || [ ! -s "$file" ] && file="$1"
  [ ! -f "$file" ] || [ ! -s "$file" ] && file="${SCRIPTPATH}/assets/$DETECTED.xml"
  [ ! -f "$file" ] || [ ! -s "$file" ] && return 1

  XML="$file"
  return 0
}

detectImage() {

  local dir="$1"
  local version="$2"
  local desc msg find language

  XML=""

  if [ -z "$DETECTED" ] && [ -z "$CUSTOM" ]; then
    [[ "${version,,}" != "http"* ]] && DETECTED="$version"
  fi

  if [ -n "$DETECTED" ]; then

    skipVersion "${DETECTED,,}" && return 0

    if ! setXML "" && [[ "$MANUAL" != [Yy1]* ]]; then
      MANUAL="Y"
      desc=$(printEdition "$DETECTED" "this version")
      warn "the answer file for $desc was not found ($DETECTED.xml), $FB."
    fi

    return 0
  fi

  info "Detecting version from ISO image..."

  if detectLegacy "$dir"; then
    desc=$(printEdition "$DETECTED" "$DETECTED")
    info "Detected: $desc"
    return 0
  fi

  local src wim info
  src=$(find "$dir" -maxdepth 1 -type d -iname sources | head -n 1)

  if [ ! -d "$src" ]; then
    warn "failed to locate 'sources' folder in ISO image, $FB" && return 1
  fi

  wim=$(find "$src" -maxdepth 1 -type f -iname install.wim | head -n 1)
  [ ! -f "$wim" ] && wim=$(find "$src" -maxdepth 1 -type f -iname install.esd | head -n 1)

  if [ ! -f "$wim" ]; then
    warn "failed to locate 'install.wim' or 'install.esd' in ISO image, $FB" && return 1
  fi

  info=$(wimlib-imagex info -xml "$wim" | tr -d '\000')
  ! checkPlatform "$info" && exit 67

  DETECTED=$(detectVersion "$info")

  if [ -z "$DETECTED" ]; then
    msg="Failed to determine Windows version from image"
    if setXML "" || [[ "$MANUAL" == [Yy1]* ]]; then
      info "${msg}!"
    else
      MANUAL="Y"
      warn "${msg}, $FB."
    fi
    return 0
  fi

  desc=$(printEdition "$DETECTED" "$DETECTED")
  detectLanguage "$info"

  if [[ "${LANGUAGE,,}" != "en" ]] && [[ "${LANGUAGE,,}" != "en-"* ]]; then
    language=$(getLanguage "$LANGUAGE" "desc")
    desc=+" ($language)"
  fi

  info "Detected: $desc"
  setXML "" && return 0

  msg="the answer file for $desc was not found ($DETECTED.xml)"
  local fallback="${SCRIPTPATH}/assets/${DETECTED%%-*}.xml"

  if setXML "$fallback" || [[ "$MANUAL" == [Yy1]* ]]; then
    [[ "$MANUAL" != [Yy1]* ]] && warn "${msg}."
  else
    MANUAL="Y"
    warn "${msg}, $FB."
  fi

  return 0
}

prepareImage() {

  local iso="$1"
  local dir="$2"
  local desc missing

  desc=$(printVersion "$DETECTED" "$DETECTED")

  ! setMachine "$DETECTED" "$iso" "$dir" "$desc" && return 1
  skipVersion "$DETECTED" && return 0

  if [[ "${BOOT_MODE,,}" != "windows_legacy" ]]; then

    [ -f "$dir/$ETFS" ] && [ -f "$dir/$EFISYS" ] && return 0

    missing=$(basename "$dir/$EFISYS")
    [ ! -f "$dir/$ETFS" ] && missing=$(basename "$dir/$ETFS")

    error "Failed to locate file \"${missing,,}\" in ISO image!"
    return 1
  fi

  prepareLegacy "$iso" "$dir" "$desc" && return 0

  error "Failed to extract boot image from ISO image!"
  return 1
}

updateXML() {

  local asset="$1"
  local language="$2"
  local culture region user admin pass keyboard

  [ -z "$YRES" ] && YRES="720"
  [ -z "$XRES" ] && XRES="1280"

  sed -i "s/<VerticalResolution>1080<\/VerticalResolution>/<VerticalResolution>$YRES<\/VerticalResolution>/g" "$asset"
  sed -i "s/<HorizontalResolution>1920<\/HorizontalResolution>/<HorizontalResolution>$XRES<\/HorizontalResolution>/g" "$asset"

  culture=$(getLanguage "$language" "culture")

  if [ -n "$culture" ] && [[ "${culture,,}" != "en-us" ]]; then
    sed -i "s/<UILanguage>en-US<\/UILanguage>/<UILanguage>$culture<\/UILanguage>/g" "$asset"
  fi

  region="$REGION"
  [ -z "$region" ] && region="$culture"

  if [ -n "$region" ] && [[ "${region,,}" != "en-us" ]]; then
    sed -i "s/<UserLocale>en-US<\/UserLocale>/<UserLocale>$region<\/UserLocale>/g" "$asset"
    sed -i "s/<SystemLocale>en-US<\/SystemLocale>/<SystemLocale>$region<\/SystemLocale>/g" "$asset"
  fi

  keyboard="$KEYBOARD"
  [ -z "$keyboard" ] && keyboard="$culture"

  if [ -n "$keyboard" ] && [[ "${keyboard,,}" != "en-us" ]]; then
    sed -i "s/<InputLocale>en-US<\/InputLocale>/<InputLocale>$keyboard<\/InputLocale>/g" "$asset"
    sed -i "s/<InputLocale>0409:00000409<\/InputLocale>/<InputLocale>$keyboard<\/InputLocale>/g" "$asset"
  fi

  user=$(echo "$USERNAME" | sed 's/[^[:alnum:]@!._-]//g')

  if [ -n "$user" ]; then
    sed -i "s/<Name>Docker<\/Name>/<Name>$user<\/Name>/g" "$asset"
    sed -i "s/where name=\"Docker\"/where name=\"$user\"/g" "$asset"
    sed -i "s/<FullName>Docker<\/FullName>/<FullName>$user<\/FullName>/g" "$asset"
    sed -i "s/<Username>Docker<\/Username>/<Username>$user<\/Username>/g" "$asset"
  fi

  if [ -n "$PASSWORD" ]; then
    pass=$(printf '%s' "${PASSWORD}Password" | iconv -f utf-8 -t utf-16le | base64 -w 0)
    admin=$(printf '%s' "${PASSWORD}AdministratorPassword" | iconv -f utf-8 -t utf-16le | base64 -w 0)
    sed -i "s/<Value>password<\/Value>/<Value>$admin<\/Value>/g" "$asset"
    sed -i "s/<PlainText>true<\/PlainText>/<PlainText>false<\/PlainText>/g" "$asset"
    sed -z "s/<Password>...........<Value \/>/<Password>\n          <Value>$pass<\/Value>/g" -i "$asset"
    sed -z "s/<Password>...............<Value \/>/<Password>\n              <Value>$pass<\/Value>/g" -i "$asset"
    sed -z "s/<AdministratorPassword>...........<Value \/>/<AdministratorPassword>\n          <Value>$admin<\/Value>/g" -i "$asset"
    sed -z "s/<AdministratorPassword>...............<Value \/>/<AdministratorPassword>\n              <Value>$admin<\/Value>/g" -i "$asset"
  fi

  return 0
}

addDriver() {

  local id="$1"
  local path="$2"
  local target="$3"
  local driver="$4"
  local folder=""

  case "${id,,}" in
    "win7x86"* ) folder="w7/x86" ;;
    "win7x64"* ) folder="w7/amd64" ;;
    "win81x64"* ) folder="w8.1/amd64" ;;
    "win10x64"* ) folder="w10/amd64" ;;
    "win11x64"* ) folder="w11/amd64" ;;
    "win2025"* ) folder="2k25/amd64" ;;
    "win2022"* ) folder="2k22/amd64" ;;
    "win2019"* ) folder="2k19/amd64" ;;
    "win2016"* ) folder="2k16/amd64" ;;
    "win2012"* ) folder="2k12R2/amd64" ;;
    "win2008"* ) folder="2k8R2/amd64" ;;
    "win10arm64"* ) folder="w10/ARM64" ;;
    "win11arm64"* ) folder="w11/ARM64" ;;
    "winvistax86"* ) folder="2k8/x86" ;;
    "winvistax64"* ) folder="2k8/amd64" ;;
  esac

  if [ -z "$folder" ]; then
    warn "no \"$driver\" driver found for \"$DETECTED\" !" && return 0
  fi

  [ ! -d "$path/$driver/$folder" ] && return 0

  case "${id,,}" in
    "winvista"* )
      [[ "${driver,,}" == "viorng" ]] && return 0
      ;;
    "win2025"* | "win11x64-iot"* | "win11x64-ltsc"* )
      [[ "${driver,,}" == "smbus" ]] && return 0
      [[ "${driver,,}" == "pvpanic" ]] && return 0
      [[ "${driver,,}" == "viogpudo" ]] && return 0
      ;;
  esac

  local dest="$path/$target/$driver"
  mv "$path/$driver/$folder" "$dest"

  return 0
}

addDrivers() {

  local file="$1"
  local index="$2"
  local version="$3"

  local msg="Adding drivers to image..."
  info "$msg"

  local drivers="$TMP/drivers"
  mkdir -p "$drivers"

  if ! tar -xf /drivers.tar.xz -C "$drivers" --warning=no-timestamp; then
    error "Failed to extract driver!" && return 1
  fi

  local target="\$WinPEDriver\$"
  local dest="$drivers/$target"
  mkdir -p "$dest"

  wimlib-imagex update "$file" "$index" --command "delete --force --recursive /$target" >/dev/null || true

  addDriver "$version" "$drivers" "$target" "qxl"
  addDriver "$version" "$drivers" "$target" "viofs"
  addDriver "$version" "$drivers" "$target" "sriov"
  addDriver "$version" "$drivers" "$target" "smbus"
  addDriver "$version" "$drivers" "$target" "qxldod"
  addDriver "$version" "$drivers" "$target" "viorng"
  addDriver "$version" "$drivers" "$target" "viostor"
  addDriver "$version" "$drivers" "$target" "NetKVM"
  addDriver "$version" "$drivers" "$target" "Balloon"
  addDriver "$version" "$drivers" "$target" "vioscsi"
  addDriver "$version" "$drivers" "$target" "pvpanic"
  addDriver "$version" "$drivers" "$target" "vioinput"
  addDriver "$version" "$drivers" "$target" "viogpudo"
  addDriver "$version" "$drivers" "$target" "vioserial"
  addDriver "$version" "$drivers" "$target" "qemupciserial"

  if ! wimlib-imagex update "$file" "$index" --command "add $dest /$target" >/dev/null; then
    return 1
  fi

  rm -rf "$drivers"
  return 0
}

addFolder() {

  local src="$1"
  local folder="/oem"

  [ ! -d "$folder" ] && folder="/OEM"
  [ ! -d "$folder" ] && folder="$STORAGE/oem"
  [ ! -d "$folder" ] && folder="$STORAGE/OEM"
  [ ! -d "$folder" ] && return 0

  local msg="Adding OEM folder to image..."
  info "$msg"

  local dest="$src/\$OEM\$/\$1/"
  mkdir -p "$dest"

  ! cp -r "$folder" "$dest" && return 1

  local file
  file=$(find "$dest" -maxdepth 1 -type f -iname install.bat | head -n 1)
  [ -f "$file" ] && unix2dos -q "$file"

  return 0
}

updateImage() {

  local dir="$1"
  local asset="$2"
  local language="$3"
  local file="autounattend.xml"
  local org="${file//.xml/.org}"
  local dat="${file//.xml/.dat}"
  local desc path src wim xml index result

  skipVersion "${DETECTED,,}" && return 0

  if [ ! -s "$asset" ] || [ ! -f "$asset" ]; then
    asset=""
    if [[ "$MANUAL" != [Yy1]* ]]; then
      MANUAL="Y"
      warn "no answer file provided, $FB."
    fi
  fi

  src=$(find "$dir" -maxdepth 1 -type d -iname sources | head -n 1)

  if [ ! -d "$src" ]; then
    error "failed to locate 'sources' folder in ISO image, $FB" && return 1
  fi

  wim=$(find "$src" -maxdepth 1 -type f -iname boot.wim | head -n 1)
  [ ! -f "$wim" ] && wim=$(find "$src" -maxdepth 1 -type f -iname boot.esd | head -n 1)

  if [ ! -f "$wim" ]; then
    error "failed to locate 'boot.wim' or 'boot.esd' in ISO image, $FB" && return 1
  fi

  index="1"
  result=$(wimlib-imagex info -xml "$wim" | tr -d '\000')

  if [[ "${result^^}" == *"<IMAGE INDEX=\"2\">"* ]]; then
    index="2"
  fi

  if ! addDrivers "$wim" "$index" "$DETECTED"; then
    error "Failed to add drivers to image!" && return 1
  fi

  if ! addFolder "$src"; then
    error "Failed to add OEM folder to image!" && return 1
  fi

  if wimlib-imagex extract "$wim" "$index" "/$file" "--dest-dir=$TMP" >/dev/null 2>&1; then
    if ! wimlib-imagex extract "$wim" "$index" "/$dat" "--dest-dir=$TMP" >/dev/null 2>&1; then
      if ! wimlib-imagex extract "$wim" "$index" "/$org" "--dest-dir=$TMP" >/dev/null 2>&1; then
        if ! wimlib-imagex update "$wim" "$index" --command "rename /$file /$org" > /dev/null; then
          warn "failed to backup original answer file ($file)."
        fi
      fi
    fi
    rm -f "$TMP/$dat"
    rm -f "$TMP/$org"
    rm -f "$TMP/$file"
  fi

  if [[ "$MANUAL" != [Yy1]* ]]; then

    xml=$(basename "$asset")
    info "Adding $xml for automatic installation..."

    local answer="$TMP/$xml"
    cp "$asset" "$answer"
    updateXML "$answer" "$language"

    if ! wimlib-imagex update "$wim" "$index" --command "add $answer /$file" > /dev/null; then
      MANUAL="Y"
      warn "failed to add answer file ($xml) to ISO image, $FB"
    else
      wimlib-imagex update "$wim" "$index" --command "add $answer /$dat" > /dev/null || true
    fi

    rm -f "$answer"

  fi

  if [[ "$MANUAL" == [Yy1]* ]]; then

    wimlib-imagex update "$wim" "$index" --command "delete --force /$file" > /dev/null || true

    if wimlib-imagex extract "$wim" "$index" "/$org" "--dest-dir=$TMP" >/dev/null 2>&1; then
      if ! wimlib-imagex update "$wim" "$index" --command "add $TMP/$org /$file" > /dev/null; then
        warn "failed to restore original answer file ($org)."
      fi
    fi

    rm -f "$TMP/$org"

  fi

  local find="$file"
  [[ "$MANUAL" == [Yy1]* ]] && find="$org"
  path=$(find "$dir" -maxdepth 1 -type f -iname "$find" | head -n 1)

  if [ -f "$path" ]; then
    if [[ "$MANUAL" != [Yy1]* ]]; then
      mv -f "$path" "${path%.*}.org"
    else
      mv -f "$path" "${path%.*}.xml"
    fi
  fi

  return 0
}

removeImage() {

  local iso="$1"

  [ ! -f "$iso" ] && return 0
  [ -n "$CUSTOM" ] && return 0
  ! rm -f "$iso" 2> /dev/null && warn "failed to remove $iso !"

  return 0
}

buildImage() {

  local dir="$1"
  local failed=""
  local cat="BOOT.CAT"
  local log="/run/shm/iso.log"
  local base size size_gb space space_gb desc

  if [ -f "$BOOT" ]; then
    error "File $BOOT does already exist?!" && return 1
  fi

  base=$(basename "$BOOT")
  local out="$TMP/${base%.*}.tmp"
  rm -f "$out"

  desc=$(printVersion "$DETECTED" "ISO")

  local msg="Building $desc image..."
  info "$msg"

  [ -z "$LABEL" ] && LABEL="Windows"

  if [ ! -f "$dir/$ETFS" ]; then
    error "Failed to locate file \"$ETFS\" in ISO image!" && return 1
  fi

  size=$(du -h -b --max-depth=0 "$dir" | cut -f1)
  size_gb=$(( (size + 1073741823)/1073741824 ))
  space=$(df --output=avail -B 1 "$TMP" | tail -n 1)
  space_gb=$(( (space + 1073741823)/1073741824 ))

  if (( size > space )); then
    error "Not enough free space in $STORAGE, have $space_gb GB available but need at least $size_gb GB." && return 1
  fi

  if [[ "${BOOT_MODE,,}" != "windows_legacy" ]]; then

    ! genisoimage -o "$out" -b "$ETFS" -no-emul-boot -c "$cat" -iso-level 4 -J -l -D -N -joliet-long -relaxed-filenames -V "${LABEL::30}" \
                  -udf -boot-info-table -eltorito-alt-boot -eltorito-boot "$EFISYS" -no-emul-boot -allow-limited-size -quiet "$dir" 2> "$log" && failed="y"

  else

    case "${DETECTED,,}" in
      "win2k"* | "winxp"* | "win2003"* )
        ! genisoimage -o "$out" -b "$ETFS" -no-emul-boot -boot-load-seg 1984 -boot-load-size 4 -c "$cat" -iso-level 2 -J -l -D -N -joliet-long \
                      -relaxed-filenames -V "${LABEL::30}" -quiet "$dir" 2> "$log" && failed="y" ;;
      "win9"* )
        ! genisoimage -o "$out" -b "$ETFS" -J -r -V "${LABEL::30}" -quiet "$dir" 2> "$log" && failed="y" ;;
      * )
        ! genisoimage -o "$out" -b "$ETFS" -no-emul-boot -c "$cat" -iso-level 2 -J -l -D -N -joliet-long -relaxed-filenames -V "${LABEL::30}" \
                      -udf -allow-limited-size -quiet "$dir" 2> "$log" && failed="y" ;;
    esac

  fi

  if [ -n "$failed" ]; then
    [ -s "$log" ] && echo "$(<"$log")"
    error "Failed to build image!" && return 1
  fi

  local error=""
  local hide="Warning: creating filesystem that does not conform to ISO-9660."

  [ -s "$log" ] && error="$(<"$log")"
  [[ "$error" != "$hide" ]] && echo "$error"

  ! mv -f "$out" "$BOOT" && return 1
  return 0
}

bootWindows() {

  rm -rf "$TMP"

  if [ -s "$STORAGE/windows.vga" ] && [ -f "$STORAGE/windows.vga" ]; then
    [ -z "${VGA:-}" ] && VGA=$(<"$STORAGE/windows.vga")
  else
    [ -z "${VGA:-}" ] && [[ "${PLATFORM,,}" == "arm64" ]] && VGA="virtio-gpu"
  fi

  if [ -s "$STORAGE/windows.type" ] && [ -f "$STORAGE/windows.type" ]; then
    [ -z "${DISK_TYPE:-}" ] && DISK_TYPE=$(<"$STORAGE/windows.type")
  fi

  if [ -s "$STORAGE/windows.mode" ] && [ -f "$STORAGE/windows.mode" ]; then
    BOOT_MODE=$(<"$STORAGE/windows.mode")
    if [ -s "$STORAGE/windows.old" ] && [ -f "$STORAGE/windows.old" ]; then
      [[ "${PLATFORM,,}" == "x64" ]] && MACHINE=$(<"$STORAGE/windows.old")
    fi
    return 0
  fi

  # Migrations

  [[ "${PLATFORM,,}" != "x64" ]] && return 0

  if [ -f "$STORAGE/windows.old" ]; then
    MACHINE=$(<"$STORAGE/windows.old")
    [ -z "$MACHINE" ] && MACHINE="q35"
    BOOT_MODE="windows_legacy"
    echo "$BOOT_MODE" > "$STORAGE/windows.mode"
    return 0
  fi

  local creation="1.10"
  local minimal="2.14"

  if [ -f "$STORAGE/windows.ver" ]; then
    creation=$(<"$STORAGE/windows.ver")
    [[ "${creation}" != *"."* ]] && creation="$minimal"
  fi

  # Force secure boot on installs created prior to v2.14
  if (( $(echo "$creation < $minimal" | bc -l) )); then
    if [[ "${BOOT_MODE,,}" == "windows" ]]; then
      BOOT_MODE="windows_secure"
      echo "$BOOT_MODE" > "$STORAGE/windows.mode"
      if [ -f "$STORAGE/windows.rom" ] && [ ! -f "$STORAGE/$BOOT_MODE.rom" ]; then
        mv -f "$STORAGE/windows.rom" "$STORAGE/$BOOT_MODE.rom"
      fi
      if [ -f "$STORAGE/windows.vars" ] && [ ! -f "$STORAGE/$BOOT_MODE.vars" ]; then
        mv -f "$STORAGE/windows.vars" "$STORAGE/$BOOT_MODE.vars"
      fi
    fi
  fi

  return 0
}

######################################

! parseVersion && exit 58
! parseLanguage && exit 56
! detectCustom && exit 59

if ! startInstall; then
  bootWindows && return 0
  exit 68
fi

if [ ! -s "$ISO" ] || [ ! -f "$ISO" ]; then
  if ! downloadImage "$ISO" "$VERSION" "$LANGUAGE"; then
    rm -f "$ISO" 2> /dev/null || true
    exit 61
  fi
fi

if ! extractImage "$ISO" "$DIR" "$VERSION"; then
  rm -f "$ISO" 2> /dev/null || true
  exit 62
fi

if ! detectImage "$DIR" "$VERSION"; then
  abortInstall "$DIR" "$ISO" && return 0
  exit 60
fi

if ! prepareImage "$ISO" "$DIR"; then
  abortInstall "$DIR" "$ISO" && return 0
  exit 66
fi

if ! updateImage "$DIR" "$XML" "$LANGUAGE"; then
  abortInstall "$DIR" "$ISO" && return 0
  exit 63
fi

if ! removeImage "$ISO"; then
  exit 64
fi

if ! buildImage "$DIR"; then
  exit 65
fi

if ! finishInstall "$BOOT" "N"; then
  exit 69
fi

# Run installation
