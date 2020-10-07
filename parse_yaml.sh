#!/usr/bin/env bash
#-----------------------------------------------------------#
# @author: dep, demmonico@gmail.com
# @link: https://github.com/demmonico
# @package: https://github.com/demmonico/bash-parse-yaml
#
# Scripts aimed in help to parse yaml file directly by Bash.
# Useful for parsing different configs.
#
# FORMAT: parse_yaml.sh <YAML_FILE_NAME> <parent1> <patent2> ... <config_key_name>
#
#-----------------------------------------------------------#


RC='\033[0;31m'
YC='\033[0;33m'
NC='\033[0m' # No Color

####################################
# get config value from yaml config
#
# format: getYamlConfigValue YAML_FILE_NAME parent1 patent2 ... config_key_name
#
function getYamlConfigValue {
  if [ "$#" -lt 2 ]; then
    echo -e "${RC}Error:${NC} too few arguments at '${YC}getYamlConfigValue${NC}'"
    exit 1
  fi

  local PREFIX='' CONFIG_YAML_FILE=$1

  local CONFIG_PATH="${PREFIX}"
  for i in "${@:2}"; do
    [ -z "${CONFIG_PATH}" ] && CONFIG_PATH="${i}" || CONFIG_PATH="${CONFIG_PATH}_${i}"
  done

  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
  sed -ne "s|,$s\]$s\$|]|" \
      -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
      -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" ${CONFIG_YAML_FILE} | \
  sed -ne "s|,$s}$s\$|}|" \
      -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
      -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
  sed -ne "s|^\($s\):|\1|" \
      -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
      -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
      -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
  # compose list of variables like parent1_parent2_target="target value"
  awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) { if (i > indent) { delete vname[i]; idx[i]=0 } };
      if (length($2) == 0) { vname[indent]= ++idx[indent] };
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'${PREFIX:+${PREFIX}_}'", vn, vname[indent], $3);
      }
   }' | \
  # filter using pattern
  grep ${CONFIG_PATH} | \
  # fetch string value or list values
  {
    local RESULT
    declare -a CONFIG_RESULTS=()
    while read line; do CONFIG_RESULTS+=("${line}"); done

    # list value
    if [[ "${#CONFIG_RESULTS[*]}" -gt 1 ]]; then
      local CONFIG_VALUES=''
      for i in "${CONFIG_RESULTS[@]}"; do
        CONFIG_KEY="$( echo "${i}" | sed -E 's/^'"${CONFIG_PATH}_"'(.*)=.*$/\1/g' )"
        # validate key should be like ${CONFIG_PATH}_<number>
        if ! [[ ${CONFIG_KEY} =~ ^[0-9]+$ ]]; then
          echo -e "${RC}Error:${NC} config path '${YC}${CONFIG_PATH}${NC}' contains non-supported value (string or list)"
          exit 1
        fi
        # collect value
        if [ -z "${CONFIG_VALUES}" ]; then
          CONFIG_VALUES="$( echo "${i}" | sed -E 's/^.*"(.*)".*$/\1/g' )"
        else
          CONFIG_VALUES="${CONFIG_VALUES}"$'\n'"$( echo "${i}" | sed -E 's/^.*"(.*)".*$/\1/g' )"
        fi
      done
      RESULT="${CONFIG_VALUES}"

    # single value
    else
      RESULT=$( echo "${CONFIG_RESULTS[@]}" | sed -E 's/^.*"(.*)".*$/\1/g' )
    fi

    echo "${RESULT}"
  }
}

getYamlConfigValue $@
