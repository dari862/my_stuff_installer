#!/bin/bash
# linux-audit v0.0.1-20231020
# Lazily wraps various Linux system auditing tools.
# Intended for personal use. Use at own risk.
# Don't run this on production systems.
# https://github.com/bcoles/linux-audit
# ~ bcoles 2019
set -euo pipefail
IFS=$'\n\t'

umask 0077

readonly _version="0.0.1-20231020"

_rel="$(dirname "$(readlink -f "$0")")"
readonly _rel

readonly _tools_directory="${_rel}/tools"
readonly _logs_directory="${_rel}/logs"

_host_name="$(hostname || uname -n)" || exit
readonly _host_name

_date="$(date +%Y%m%d%H%M%S)" || exit
readonly _date

readonly _audit_name="${_host_name}-${_date}-linux-audit"
readonly _audit_directory="${_logs_directory}/${_audit_name}"

# Enable automatic updating of dependencies
readonly _update_deps="true"

user_mod=""

function error() { echo -e "\\033[1;31m[-]\\033[0m  $*"; exit 1 ; }
function say() { echo -e "--[ \\033[1;32m$*\\033[0m ]--"; }
function warn() { echo -e "\\033[1;33m[!]\\033[0m  $*"; }
function info() { echo -e "\\033[1;34m[*]\\033[0m  $*"; }

function audit() {
  mkdir -p "${_audit_directory}"

  echo
  info "Date:\t$(date)"
  info "Hostname:\t${_host_name}"
  info "System:\t$(uname -a)"
  info "User:\t$(id)"
  info "Log:\t${_audit_directory}"
  echo

  if [ "$(id -u)" -eq 0 ]; then
    info "Running privileged checks..."
  	echo
  	user_mod="root"
  	check_pentest
  else
  	info "Running unprivileged checks..."
  	echo
  	check_pentest
  fi
}

function command_exists () {
  command -v "${1}" >/dev/null 2>&1
}

function setup() {
  mkdir -p "${_tools_directory}"

  info "Checking dependencies..."

  if ! command_exists git ; then
    error "git is not in \$PATH"
  fi

  if ! command_exists python3 ; then
    warn "python3 is not in \$PATH! Some checks will be skipped ..."
  fi

  set +e
  	IFS=' ' read -r -d '' -a array <<-'_EOF_'
	https://github.com/mzet-/linux-exploit-suggester
	https://github.com/CISOfy/lynis
	https://github.com/bcoles/so-check
	https://github.com/initstring/uptux
	https://github.com/lateralblast/lunar
	https://github.com/diego-treitos/linux-smart-enumeration
	https://github.com/a13xp0p0v/kernel-hardening-checker
	https://github.com/bcoles/jalesc
	https://github.com/rebootuser/LinEnum
	https://github.com/trimstray/otseca
	https://github.com/slimm609/checksec.sh
	_EOF_
  set -e

  while read -r repo; do
    tool=${repo##*/}

    [ -z "${repo}" ] && continue

    if [ -d "${_tools_directory}/${tool}" ]; then
      if [ "${_update_deps}" = "true" ]; then
        info "Updating ${tool} ..."
        bash -c "cd ${_tools_directory}/${tool}; git pull"
      fi
    else
      info "Fetching ${tool} ..."
      git clone "${repo}" "${_tools_directory}/${tool}"
    fi
  done <<< "${array}"
  
  linpeas_sh_url="https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh"
  if command_exists wget ; then
    info "Fetching LinPEAS ..."
    wget ${linpeas_sh_url} -O "${_tools_directory}/linpeas.sh"
  elif command_exists curl ; then
    info "Fetching LinPEAS ..."
    curl -SL --progress-bar ${linpeas_sh_url} -o "${_tools_directory}/linpeas.sh"
  else
    warn "linpeas.sh checks will be skipped ..."
  fi

  #if command_exists "apt-get"; then
  #  # Debian / Ubuntu
  #  apt-get -y install libopenscap8
  #elif command_exists "yum" ; then
  #  # CentOS / RHEL
  #  yum -y install openscap-scanner scap-security-guide
  #elif command_exists "dnf"; then
  #  # Fedora
  #  dnf -y install openscap-scanner
  #fi
}

function check_pentest() {
  info "Running linux-exploit-suggester..."
  cd "${_tools_directory}/linux-exploit-suggester" || exit
  bash "./linux-exploit-suggester.sh" --checksec | tee "${_audit_directory}/les-checksec.log"
  bash "./linux-exploit-suggester.sh" | tee "${_audit_directory}/les.log"

  info "Running lynis..."
  [ "${user_mod}" = "root" ] && chown -R 0:0 "${_tools_directory}/lynis"
  cd "${_tools_directory}/lynis" || exit
  if [ "${user_mod}" = "root" ];then
    ./lynis --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system
  else
    ./lynis --pentest --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system
  fi
  cd "${_rel}" || exit
 
  if [ "${user_mod}" = "root" ];then
  	info "Running lunar..."
  	cd "${_tools_directory}/lunar" || exit
  	bash "./lunar.sh" -a | tee "${_audit_directory}/lunar.log"
  else
    info "Running so-check..."
    cd "${_tools_directory}/so-check"
    bash "./so-check.sh" | tee "${_audit_directory}/so-check.log"
  fi
  
  if command_exists python3 ; then
    info "Running kernel-hardening-checker..."
    cd "${_tools_directory}/kernel-hardening-checker/bin" || exit
    python3 "./kernel-hardening-checker" -l /proc/cmdline -c "/boot/config-$(uname -r)" | tee "${_audit_directory}/kernel-hardening-checker.log"
  fi
  
  if [ "${user_mod}" = "root" ];then
  	info "Running otseca..."
  	cd "${_tools_directory}/otseca/bin" || exit
  	bash "./otseca" --ignore-failed --format html --output "${_audit_directory}/otseca-report"
  else
  	if command_exists python3 ; then
    	info "Running uptux..."
    	cd "${_tools_directory}/uptux" || exit
    	python3 "./uptux.py" -n | tee "${_audit_directory}/uptux.log"
  	fi
	
  	info "Running jalesc ..."
  	cd "${_tools_directory}/jalesc" || exit
  	bash "./jalesc.sh" | tee "${_audit_directory}/jalesc.log"
	
  	info "Running LinEnum ..."
  	cd "${_tools_directory}/LinEnum" || exit
  	bash "./LinEnum.sh" -t -r "${_audit_directory}/LinEnum.log"
	
  	info "Running linux-smart-enumeration..."
  	cd "${_tools_directory}/linux-smart-enumeration" || exit
  	bash "./lse.sh" -i -l1 | tee "${_audit_directory}/lse.log"
	
  	info "Running PEAS..."
  	cd "${_tools_directory}" || exit
  	bash "./linpeas.sh" | tee "${_audit_directory}/linpeas.log"
  fi
  
  info "Running checksec..."
  cd "${_tools_directory}/checksec.sh" || exit
  bash "./checksec" --proc-all | tee "${_audit_directory}/checksec-proc-all.log"

  # RHEL / CentOS
  #if command_exists oscap ; then
  #  oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig-rhel7-disa --results-arf "${_audit_directory}/oscap-arf.xml" --report "${_audit_directory}/oscap-report.html" /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
  #fi
}

# Main

say "linux-audit v${_version}"
echo
setup
audit
info "Complete"
exit 0
