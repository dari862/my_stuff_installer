#!/bin/sh
set -e

umask 0077

_rel="$(cd "$(dirname "$0")" && pwd)"
_tools_directory="${_rel}/tools"
_logs_directory="${_rel}/logs"

_host_name="$(hostname)"
_date="$(date +%Y%m%d%H%M%S)"
_audit_name="${_host_name}-${_date}-linux-audit"
_audit_directory="${_logs_directory}/${_audit_name}"

_update_deps="true"

common_repos="https://github.com/mzet-/linux-exploit-suggester
https://github.com/CISOfy/lynis
https://github.com/a13xp0p0v/kernel-hardening-checker
https://github.com/slimm609/checksec.sh
"

repos_for_root="${common_repos}
https://github.com/lateralblast/lunar
https://github.com/trimstray/otseca
"

repos_for_normal_user="${common_repos}
https://github.com/bcoles/so-check
https://github.com/initstring/uptux
https://github.com/bcoles/jalesc
https://github.com/rebootuser/LinEnum
https://github.com/diego-treitos/linux-smart-enumeration
"

linpeas_sh_url="https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh"

if [ "$(id -u)" -eq 0 ]; then
    user_mod="root"
    repos="${repos_for_root}"
else
    user_mod=""
    repos="${repos_for_normal_user}"
fi

error() {
    printf '%b' "\\033[1;31m[-]\\033[0m$*\n"
    exit 1
}

say() {
    printf '%b' "\n\n==[ \\033[1;32m$*\\033[0m ]==\n\n"
}

warn() {
    printf '%b' "\\033[1;33m[!]\\033[0m$*\n"
}

info() {
    printf '%b' "\\033[1;34m[*]\\033[0m$*\n"
}

command_exists() {
    type "$1" >/dev/null 2>&1
}

package_exists() {
    dpkg-query -W "$1" >/dev/null 2>&1
}

establish_necessary_dirs() {
    mkdir -p "${_tools_directory}" "${_audit_directory}"
}

check_dependencies() {
    info "Checking dependencies..."

    if ! command_exists git; then
        error "git is not in \$PATH"
    fi

    if ! command_exists python3; then
        warn "python3 is not in \$PATH! Some checks will be skipped ..."
    fi

    if ! package_exists binutils; then
        warn "package binutils is missing. checksec will be skipped ..."
        warn "apt install -y binutils"
        warn "to fix it."
    fi
}

fetch_repos() {
    for repo in $repos; do
        tool=$(basename "$repo")
        [ -z "$repo" ] && continue

        if [ -d "${_tools_directory}/${tool}" ]; then
            if [ "${_update_deps}" = "true" ]; then
                info "Updating ${tool} ..."
                (cd "${_tools_directory}/${tool}" && git pull)
            fi
        else
            info "Fetching ${tool} ..."
            git clone "$repo" "${_tools_directory}/${tool}"
        fi
    done
}

fetch_linpeas() {
    if command_exists wget; then
        info "Fetching LinPEAS ..."
        wget "$linpeas_sh_url" -O "${_tools_directory}/linpeas.sh"
    elif command_exists curl; then
        info "Fetching LinPEAS ..."
        curl -SL --progress-bar "$linpeas_sh_url" -o "${_tools_directory}/linpeas.sh"
    else
        warn "linpeas.sh checks will be skipped ..."
    fi
}

run_audit() {
    say "Running Linux audit..."
    
    run_linux_exploit_suggester
   
    if [ "$user_mod" = "root" ]; then
        run_privileged_checks
    else
        run_unprivileged_checks
    fi

    info "Audit complete"
}

run_linux_exploit_suggester() {
    info "Running linux-exploit-suggester..."
    cd "${_tools_directory}/linux-exploit-suggester" || exit
    bash "./linux-exploit-suggester.sh" --checksec | tee "${_audit_directory}/les-checksec.log"
    bash "./linux-exploit-suggester.sh" | tee "${_audit_directory}/les.log"
}

run_privileged_checks() {
    info "Running privileged checks..."
    cd "${_tools_directory}/lynis" || exit
    chown -R 0:0 "${_tools_directory}/lynis"
    bash "./lynis" --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system

    info "Running lunar..."
    cd "${_tools_directory}/lunar" || exit
    bash "./lunar.sh" -a | tee "${_audit_directory}/lunar.log"

    info "Running otseca..."
    cd "${_tools_directory}/otseca/bin" || exit
    bash "./otseca" --ignore-failed --format html --output "${_audit_directory}/otseca-report"
}

run_unprivileged_checks() {
    info "Running unprivileged checks..."
    cd "${_tools_directory}/lynis" || exit
    bash "./lynis" --pentest --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system

    info "Running so-check..."
    cd "${_tools_directory}/so-check" || exit
    bash "./so-check.sh" | tee "${_audit_directory}/so-check.log"

    if command_exists python3; then
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
}

main() {
    establish_necessary_dirs
    check_dependencies
    fetch_repos
    fetch_linpeas
    run_audit
}

main
