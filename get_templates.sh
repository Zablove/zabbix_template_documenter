#!/bin/bash

show_help() {
  echo "Use: $0 -t <token> -z <zabbix API URL> -o <output_dir>"
  echo "  -t <token>: Zabbix API token with at least rights to read Zabbix Templates"
  echo "  -z Zabbix API URL (example: https://example.com/zabbix/api_jsonrpc.php)"
  echo "  -o Output dir where templates where stored (example: /tmp/json)"
  exit 1
}

token=""
zbx_api_ur=""
json_dir=""

while getopts ":t:o:z:h:" opt; do
  case ${opt} in
    t )
      token=$OPTARG
      ;;
    z )
      zbx_api_url=$OPTARG
      ;;
    o )
      json_dir=$OPTARG
      ;;
    h )
      show_help
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      show_help
      exit 1
      ;;
  esac
done

if [ -z "$token" ]; then
  echo "Option -t is required" >&2
  show_help
fi
if [ -z "$zbx_api_url" ]; then
  echo "Option -z is required" >&2
  show_help
fi
if [ -z "$json_dir" ]; then
  echo "Option -o is required" >&2
  show_help
else
  # Make sure path ends with /
  if [ "${json_dir: -1}" != "/" ]; then
      json_dir="${json_dir}/"
  fi
fi

## Check if directory exists
if [ ! -d "$json_dir" ]; then
    echo "Directory $json_dir does not exist, create it yourself"
    exit 1
fi

echo "Token = $token"
echo "ZBX API URL = $zbx_api_url"
echo "Output dir = $json_dir"
id='1'

## Get all template ID's:
result=`curl -X POST -s -H 'Content-Type:application/json' -d '{ "jsonrpc": "2.0", "method": "template.get", "params": { "output": ["hostid"]}, "auth":"'"$token"'", "id": '"$id"' }' $zbx_api_url | jq -r .result[].templateid`


## Download all templates in json format
for number in $result; do
  curl -X POST -s -H 'Content-Type:application/json' -d '{ "jsonrpc": "2.0", "method": "configuration.export", "params": { "options": { "templates": [ '"$number"' ]},"format": "json"}, "auth":"'"$token"'", "id": '"$id"' }' $zbx_api_url | jq -r .result >> $json_dir$number.json
done
