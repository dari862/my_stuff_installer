#!/bin/sh
set -e

umask 0077

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
repos=""
	
repo_array_root="
https://github.com/mzet-/linux-exploit-suggester
https://github.com/CISOfy/lynis
https://github.com/lateralblast/lunar
https://github.com/trimstray/otseca
https://github.com/a13xp0p0v/kernel-hardening-checker
https://github.com/slimm609/checksec.sh
"

repo_array="
https://github.com/mzet-/linux-exploit-suggester
https://github.com/CISOfy/lynis
https://github.com/bcoles/so-check
https://github.com/initstring/uptux
https://github.com/bcoles/jalesc
https://github.com/rebootuser/LinEnum
https://github.com/diego-treitos/linux-smart-enumeration
https://github.com/a13xp0p0v/kernel-hardening-checker
https://github.com/slimm609/checksec.sh
"

linpeas_sh_url="https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh"

if [ "$(id -u)" -eq 0 ]; then
	user_mod="root"
	repos="${repo_array_root}"
else
	user_mod=""
	repos="${repo_array}"
fi


error() { printf '%b' "\\033[1;31m[-]\\033[0m$*\n"; exit 1 ; }
say() { printf '%b' "\n\n==[ \\033[1;32m$*\\033[0m ]==\n\n"; }
warn() { printf '%b' "\\033[1;33m[!]\\033[0m$*\n"; }
info() { printf '%b' "\\033[1;34m[*]\\033[0m$*\n"; }
command_exists () { command -v "${1}" >/dev/null 2>&1 ; }
package_exists () { dpkg-query -W "${1}" >/dev/null 2>&1 ; }

Main() {
	say "Download and run linux auditing scripts."
	echo
	mkdir -p "${_tools_directory}"
	
	info "Checking dependencies..."
	
	if ! command_exists git ; then
		error "git is not in \$PATH"
	fi
	
	if ! command_exists python3 ; then
		warn "python3 is not in \$PATH! Some checks will be skipped ..."
	fi
	
	if ! package_exists binutils ; then
		warn "package binutils is missing. checksec will be skipped ..."
		warn "apt install -y binutils"
		warn "to fix it."
	fi
		
	for repo in ${repos};do
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
	done

	if command_exists wget ; then
		info "Fetching LinPEAS ..."
		wget ${linpeas_sh_url} -O "${_tools_directory}/linpeas.sh"
	elif command_exists curl ; then
		info "Fetching LinPEAS ..."
		curl -SL --progress-bar ${linpeas_sh_url} -o "${_tools_directory}/linpeas.sh"
	else
		warn "linpeas.sh checks will be skipped ..."
	fi

	if [ "${user_mod}" = "root" ];then
		info "Running privileged checks..."
		echo
	else
		info "Running unprivileged checks..."
		echo
	fi
	
	mkdir -p "${_audit_directory}"
	echo
	info "Date:\t$(date)"
	info "Hostname:\t${_host_name}"
	info "System:\t$(uname -a)"
	info "User:\t$(id)"
	info "Log:\t${_audit_directory}"
	echo
	run_audit
	info "Complete"
	exit 0	
}

run_audit() {
	info "Running linux-exploit-suggester..."
	cd "${_tools_directory}/linux-exploit-suggester" || exit
	bash "./linux-exploit-suggester.sh" --checksec | tee "${_audit_directory}/les-checksec.log"
	bash "./linux-exploit-suggester.sh" | tee "${_audit_directory}/les.log"

	if [ "${user_mod}" = "root" ];then
		info "Running lynis..."
		chown -R 0:0 "${_tools_directory}/lynis"
		cd "${_tools_directory}/lynis" || exit
		./lynis --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system
		info "Running lunar..."
		cd "${_tools_directory}/lunar" || exit
		bash "./lunar.sh" -a | tee "${_audit_directory}/lunar.log"
		info "Running otseca..."
		cd "${_tools_directory}/otseca/bin" || exit
		bash "./otseca" --ignore-failed --format html --output "${_audit_directory}/otseca-report"
	else
		info "Running lynis..."
		cd "${_tools_directory}/lynis" || exit
		./lynis --pentest --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system
		info "Running so-check..."
		cd "${_tools_directory}/so-check"
		bash "./so-check.sh" | tee "${_audit_directory}/so-check.log"
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

	if command_exists python3 ; then
		info "Running kernel-hardening-checker..."
		cd "${_tools_directory}/kernel-hardening-checker/bin" || exit
		python3 "./kernel-hardening-checker" -l /proc/cmdline -c "/boot/config-$(uname -r)" | tee "${_audit_directory}/kernel-hardening-checker.log"
	fi
 	
 	if ! package_exists binutils ; then
		info "Running checksec..."
		cd "${_tools_directory}/checksec.sh" || exit
		bash "./checksec" --proc-all | tee "${_audit_directory}/checksec-proc-all.log"
	fi
}

# Main
Main
