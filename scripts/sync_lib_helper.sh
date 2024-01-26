#!/bin/bash

main() {
  : Entry point
  #  update_db modules/perception/onboard/component:libcamera_dvr_component.so modules/perception/onboard/component:libcamera_pylon_side_component.so
  #  update_lib build_avm.sh didi@172.29.147.15:~/guoshunw/toboard "didi" "/system/apollo/internal_libs"
  #  sync_lib_for_15
  #  remote_scp aa didi@172.29.147.15:~/guoshunw/toboard didi
  #   remote_cmd didi@172.29.147.15 didi ls
  # fix_display_forward

#  alias 15_forward_adb='forward_adb didi@dev15 didi'
#  alias 28_forward_adb='forward_adb didi@bdev28 123456'
#  local my_ip=$(ip addr show dev ens33 | grep inet | head -n 1 | awk '{print $2}')
#  if [[ ${my_ip} == 192.168.0* ]]; then
#    printf "Seems home network, don't auto connect board devices.\n"
#  else
#    : Change here.
#    #adb devices | grep -q "dev15" || forward_adb didi@dev15 didi
#  fi

  # auto forward 15 if not exists
}


b73_forward_adb() {

  local serial=${1:-${ANDROID_SERIAL:-86090b83}}
  forward_adb didi@dev73 didi ${serial}
}



set_build_system() {

  local to_set=${1:-android}
  local file_to_modify=~/.bazelrc

  local project_dir=${HOME}/projects/as-houyi

  if [[ "android" == "${to_set}" ]]; then
    cfg=android_arm64-v8a
    other=x86_64_optimize
    workspace_file=${project_dir}/WORKSPACE.default/WORKSPACE.android

  elif [[ "linux" == "${to_set}" ]]; then
    cfg=x86_64_optimize
    other=android_arm64-v8a
    workspace_file=${project_dir}/WORKSPACE.default/WORKSPACE
  else
    printf "unknown os %s to set.\n" "${to_set}"
    return 1
  fi

  printf "Set current build system to %s, config=%s...\n" "${to_set}" "${cfg}"
  if [[ ! -f ${workspace_file} ]]; then
    printf "workspace file %s doesn't found.\n" "${workspace_file}"
    return 2
  fi

  cp -v "${workspace_file}" "${project_dir}/WORKSPACE"
  sed -i s/--config=${other}/--config=${cfg}/g ${file_to_modify}
}

fix_display_forward() {
  eval "$(tmux showenv -s | grep -E '^(SSH|DISPLAY)')"
}

conn_vpn() {
  sudo nmcli c u didichuxing --ask
}

update_db_usage() {
  : Usage
  printf "Usage: %s [ -h | --help ] [ -v | -- verbose ] [ --os os ] modules...
\n" "update_db"
  return 2
}

# got the os, modules parameters from different location with priority
#
update_db() {

  local os=""
  local verbose=false
  #  https://blog.csdn.net/arpospf/article/details/103381621
  #  https://www.shellscript.sh/tips/getopt/index.html
  local bazel_arguments=$(getopt -o vs:h -l help::,os:,verbose -n "${0}" -- "$@")
  [[ ${?} -eq 0 ]] || return 1

  # assign the normalized cmd arguments to the parameter position($1,$2,....)
  eval set -- "$bazel_arguments"
  #  echo formatted parameters=[$@]

  while true; do
    case "$1" in
    -h | --help)
      update_db_usage "${@}"
      local ret=$?
      shift
      return $ret
      ;;
    -s | --os)
      os=${2}
      shift 2
      ;;
    -v | --verbose)
      verbose=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      printf "Internal error: %s!\n" "${1}"
      return 1
      ;;
    esac
  done
  # if no os in argument, get it from last build command
  local last_build_cmd=$(history | grep -v history | egrep '[[:digit:]]+\s+bazel\s+build\s+' | tail -n1 | awk '{$1=""; print }' | xargs)

    printf "os=%s, modules=%s, bazel_arguments=%s\n" "${os}" "${modules}" "${bazel_arguments}"

  # read os info from last command
  if [[ -z "${os}" ]]; then
    local build_cfg=""
    if echo "${last_build_cmd}" | grep -q '\-\-config='; then
      local build_cfg_from_cmd=${last_build_cmd##*--config=}
      build_cfg_from_cmd=${build_cfg_from_cmd%% *}
      build_cfg=${build_cfg_from_cmd}
    else
      printf "Extract config from ~/.bazelrc file...\n"
      config_os=$(grep '\-\-config=' ~/.bazelrc | awk '{print $2}')
      config_os="${config_os##*--config=}"

      build_cfg="${config_os}"
    fi
        printf "last_build_cmd=\"%s\", build_cfg=\"%s\"\n" "${last_build_cmd}" "${build_cfg}"
    # read os info from config file
    if [[ $build_cfg = android* ]]; then
      os=android
    elif [[ $build_cfg = x86_64_* ]]; then
      os=linux
    else
      printf "unknown config %s\n" "${build_cfg}"
      return 1
    fi
  fi
  target_modules=$@
  if [[ -z "${target_modules}" ]]; then
    #    update_db_usage "$@"
    printf "Load build target_modules from last build command: \"%s\"\n" "${last_build_cmd}"
    target_modules=${last_build_cmd##*${build_cfg_from_cmd:-build}}
    # remove the next commands from target_modules
    target_modules=${target_modules%%;*}
    target_modules=${target_modules%%&*}
    target_modules=${target_modules%%||*}
    # trim
    target_modules=$(echo "${target_modules}" | xargs)

    # remove the build arguments for bazel
    local remain_options=""
    if echo "${target_modules}" | grep -q -; then
      remain_options="${target_modules#* -}"
      remain_options="-${remain_options}"
      target_modules=${target_modules%%-*}
    fi
  fi
  #  printf "verbose=%s, os=%s, target_modules=[%s], remain_options=%s\n" "${verbose}" "${os}" "${target_modules}" "${remain_options}"

  local bazel_arguments=""
  if [[ "android" == "${os}" ]]; then
    bazel_arguments+="--config=android_arm64-v8a"
  elif [[ "linux" == "${os}" ]]; then
    bazel_arguments+="--config=x86_64_optimize"
  fi

  if [[ -n "${config_os}" ]]; then
    printf "Ignore os parameter \"%s\" since it is configured to \"%s\" in config file %s\n" "${os}" "${config_os}" "${HOME}/.bazelrc"
    bazel_arguments=""
  fi

  if [[ "true" == "${verbose}" ]]; then
    printf "os=%s, target_modules=%s, bazel_arguments=%s\n" "${os}" "${target_modules}" "${bazel_arguments}"
  fi

  # don't use quotation mark around the ${target_modules} and ${bazel_arguments} because they are list
  bazel-compdb -s -q ${target_modules} -- ${bazel_arguments} && (
    # backup the original one
    cp ~/projects/as-houyi/compile_commands.json ~/projects/as-houyi/compile_commands.json.bak
    # fix and strip compile_commands.json after generate
    ~/./strip_command_db.py -i ~/projects/as-houyi/compile_commands.json -o ~/projects/as-houyi/compile_commands.json
  )
}

forward_adb() {
  local relay_host=${1}
  local relay_host_pass=${2}
  local device=${3:-""}

  local refresh="false"

  [[ -n "${device}" ]] && refresh="true"

  if [[ $# -lt 2 ]]; then
    printf "Usage: %s %s %s %s\n" "${FUNCNAME[0]}" "relay_host" "relay_host_pass" "device"
    return 1
  fi

  local ADB="adb"
  printf "Creating adb forward on host %s" "${relay_host}"

  if [[ -n "${device}" ]]; then
    ADB="adb -s ${device}"
    printf " for device %s" "${device}"
  fi
  printf "...\n"


  # define the relay and listening port
  local adb_board_port=5555
  local relay_host_relay_port=4000
  local relay_host_listen_port=8000

  if [[ "true" == "${refresh}" ]]; then
    printf "Multiple device, killing forward from %s:%d to board:%d to refresh connection...\n" "${relay_host}" ${relay_host_relay_port} ${adb_board_port}
    remote_cmd "${relay_host_pass}" "${relay_host}" "adb forward --remove-all"
  fi
  if ! (remote_cmd "${relay_host_pass}" "${relay_host}" "${ADB} forward --list | grep -q 'tcp:${relay_host_relay_port}'"); then
    printf "Forward from %s:%d to board:%d...\n" "${relay_host}" ${relay_host_relay_port} ${adb_board_port}
    remote_cmd "${relay_host_pass}" "${relay_host}" "${ADB} forward tcp:${relay_host_relay_port} tcp:${adb_board_port}"

    if [[ $? -ne 0 ]]; then
      remote_cmd "${relay_host_pass}" "${relay_host}" "${ADB} devices"
    fi
  fi

  if ! (remote_cmd "${relay_host_pass}" "${relay_host}" "ss -tln |  grep -q ${relay_host_listen_port}"); then
    printf "Forward from replay %s:%d to %s:%d\n" "${relay_host}" ${relay_host_listen_port} "${relay_host}" ${relay_host_relay_port}
    remote_cmd "${relay_host_pass}" "${relay_host}" "nohup socat -d -d -lf /home/didi/tmp/socat_adb.log tcp-listen:${relay_host_listen_port},reuseaddr,fork tcp:localhost:${relay_host_relay_port} 2>/dev/null &"
  fi

  local relay_host_ip=${relay_host##*@}
  if [[ "true" == "${refresh}" ]]; then
    adb disconnect
  fi
  printf "ADB auto connect to %s:%d\n" "${relay_host_ip}" ${relay_host_listen_port}
  adb connect "${relay_host_ip}:${relay_host_listen_port}" && adb devices


  # if ! (adb devices | grep -q "${relay_host_ip}"); then
  #   printf "ADB auto connect to %s:%d\n" "${relay_host_ip}" ${relay_host_listen_port}
  #   adb connect "${relay_host_ip}:${relay_host_listen_port}" && adb devices
  # fi
  #  export ANDROID_SERIAL="${relay_host_ip}:${relay_host_listen_port}"


  return 0
}
# sync libraries for 15 host
sync_lib_for_73() {
  local lib_name=${1}
  local target_directory=${2:-"/system/apollo/internal_libs"}
  update_lib "${lib_name}" didi@172.29.147.73:~/guoshunw/toboard "didi" "${target_directory}"
}

find_component_lib() {
  local component_name=$1
  local prefix=${HOME}/projects/as-houyi/bazel-bin
  local slavery_lib_name=$(printf "*%s_lib.so" "${component_name%%.*}" | sed -e "s/_/_U/g")
  local slavery_lib=$(find "${prefix}/" -name "${slavery_lib_name}" | head -n1)
  printf "component %s slavery lib: %s\n" $component_name $slavery_lib
}

update_component() {
  local component_name=$1
  # sync lib name
  local sync_lib_fun=${2:-sync_lib_for_15}

  local prefix=${HOME}/projects/as-houyi/bazel-bin

  if [[ ! -L "${prefix}" ]]; then
    printf "%s directory link doesn't exists.\n" "${prefix}"
    return 2
  fi

  local lib_location=$(find "${prefix}/" -name "${component_name}" | head -n1)
  if [[ -z "${lib_location}" ]]; then
    printf "Main library for component %s not found.\n" "${component_name}"
    return 1
  fi

  echo "-----------Begin install shared libraries for component ${component_name}-----------"

  printf "Install main so at \"%s\"...\n" "${lib_location}"
  local main_lib_target_loc=/system/apollo${lib_location#${prefix}}
  #  printf "Main so target location: %s\n" "${main_lib_target_loc}"
  "$sync_lib_fun" "${lib_location}" "${main_lib_target_loc}"

  local slavery_lib_name=$(printf "*%s_lib.so" "${component_name%%.*}" | sed -e "s/_/_U/g")
  local slavery_lib=$(find "${prefix}/" -name "${slavery_lib_name}" | head -n1)

  if [[ -z "${slavery_lib}" ]]; then
    printf "Slavery library for component %s not found.\n" "${component_name}"
    return 1
  fi
  printf "Install slavery so at \"%s\"...\n" "${slavery_lib}"
  "$sync_lib_fun" "${slavery_lib}" /system/apollo/internal_libs

  echo "===========Install shared libraries for component ${component_name} done==========="
}

update_components() {
  local components=${1}
  local sync_lib_fun=${2:-sync_lib_for_15}

  for component in ${components}; do
    update_component "${component}" "${sync_lib_fun}"
  done
}

remote_cmd() {
  if [[ $# -lt 3 ]]; then
    #    echo "num: $#"
    printf "%s %s %s %s\n" ${FUNCNAME[0]} remote_host_password remote_host cmd
    return 1
  fi
  local remote_host_pass=${1}
  local remote_host=${2}
  local cmd=${3}

  # construct remote cmd
  printf -v PASSWORD_PREFIX "sshpass -p %s" "${remote_host_pass}"
  printf -v REMOTE_CMD "%s ssh %s %s" "${PASSWORD_PREFIX}" "${remote_host}" "${cmd}"
  #  printf "REMOTE_CMD: %s\n" "${REMOTE_CMD}"
  ${REMOTE_CMD}
}

remote_scp() {
  local remote_host_pass=${1}
  local source=${2}
  local remote_host_target=${3}

  printf "Copy %s to %s...\n" "${source}" "${remote_host_target}"

  # construct remote cmd
  printf -v PASSWORD_PREFIX "sshpass -p %s" "${remote_host_pass}"
  local isDir=""
  [[ -d "${source}" ]] && isDir="-r"

  printf -v REMOTE_COPY "%s scp ${isDir} %s %s" "${PASSWORD_PREFIX}" "${source}" "${remote_host_target}"
  #  printf "CMD: %s\n" "${REMOTE_COPY}"
  ${REMOTE_COPY}
}

sync_lib_for_15() {
  local lib_name=${1}
  local target_directory=${2:-"/system/apollo/internal_libs"}
  update_lib "${lib_name}" didi@172.29.147.15:~/guoshunw/toboard "didi" "${target_directory}"
}

sync_all() {
  : Sync all package files into board
  local build_script="${1:-build_android_laneloc.sh}"
  shift
  local pack_script="${1:-laneloc_pack_opt.sh}"
  shift
  local output_dir="${1:-/apollo/output}"

  local workdir=/apollo
  local output_tar=/apollo/output.tar

  local upstream_host_directory=${UPSTREAM_HOST##*:}
  local upstream_host_ip=${UPSTREAM_HOST%%:*}

  local REMOTE_CMD="remote_cmd ${UPSTREAM_HOST_PASS} ${upstream_host_ip}"
  local REMOTE_SCP="remote_scp ${UPSTREAM_HOST_PASS}"

  cd "${workdir}"
  printf "Build script %s, and pack_script %s\n" "${build_script}" "${pack_script}"

  # 1. do the build
  bash "${build_script}"
  # clean before pack
  rm -rf "${output_dir}"
  bash "${pack_script}"
  [[ -e "${output_tar}" ]] && rm -rf "${output_tar}"
  # create tar
  tar -C "${output_dir}" -cf "${output_tar}" apollo
  # transfer to upstream hostl
  (
    ${REMOTE_CMD} "chmod -R u+w ${upstream_host_directory}/${output_tar##*/}"
    ${REMOTE_SCP} ${output_tar} ${UPSTREAM_HOST}
  )
  # unpack on remote host
  (
    printf "Unpack on upstream_host %s...\n" "${upstream_host_ip}"
    ${REMOTE_CMD} "cd ${upstream_host_directory}; tar -xf ${output_tar##*/}"
  )
  # push the archive into board
  (
    printf "Upload to board...\n"
    ${REMOTE_CMD} "adb push ${upstream_host_directory}/apollo /system"
  )
}

# Update target library on 8155 board
update_lib() {

  local lib_name=${1}
  local upstream_host=${2}
  local upstream_host_pass=${3}
  local target_directory=${4}

  #    printf "count = %d, real=%d\n" "$#" "${param_count}"

  if [[ $# -lt 4 ]]; then
    printf "Usage %s library_name upstream_host upstream_host_password target_directory\n" "$0"
    return 1
  fi

  if [[ -z "${lib_name}" ]]; then
    printf "library_name cannot be empty\n"
    return 2
  fi

  if [[ -z "${target_directory}" ]]; then
    printf "target_directory cannot be empty\n"
    return 2
  fi

  if [[ ! -e ${lib_name} ]]; then
    printf "File %s cannot found.\n" "$lib_name"
    return 3
  fi

  printf "Copy %s to %s through %s...\n" "$lib_name" "$target_directory" "$upstream_host"
  local upstream_host_directory=${upstream_host##*:}
  local upstream_host_ip=${upstream_host%%:*}

  # construct remote cmd
  printf -v PASSWORD_PREFIX "sshpass -p %s" "${upstream_host_pass}"
  printf -v REMOTE_CMD "%s ssh %s" "${PASSWORD_PREFIX}" "${upstream_host_ip}"
  printf -v SCP "%s scp" "${PASSWORD_PREFIX}"

  #    printf "REMOTE_CMD: %s\n       SCP: %s\n" "${REMOTE_CMD}" "${SCP}"

  # create remote directory if it doesn't exists
  ${REMOTE_CMD} "[[ ! -d ${upstream_host_directory} ]] && mkdir -p ${upstream_host_directory}"

  # copy to jump host
  ${SCP} "${lib_name}" "${upstream_host}"
  # change it to writeable to avoid copy issue
  local base_lib_name=${lib_name##*/}
  ${REMOTE_CMD} "chmod u+w ${upstream_host_directory}/${base_lib_name}"
  ${REMOTE_CMD} "adb push --sync ${upstream_host_directory}/${base_lib_name} ${target_directory}"
}

main "$@"
