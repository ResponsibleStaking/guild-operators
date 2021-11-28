#!/usr/bin/env bash

######################################
# User Variables - Change as desired #
# Common variables set in env file   #
######################################

#
# Todo:
#  - [x] Move check tip to function
#  - [x] Add handling of ssl to SCHEME if haproxy.cfg defines endpoint with name
#  - [x] Move hard coded values to environment variables that can be overridden
#  - [x] Add check_endpt_get (parameters: [endpoint starting from /] [rpc|view]
#  - [x] Add comparisons for RPC structure itself (prefer local, as it only impacts failover 'from' local instance, and allows to test different branches
#        This comparison is purely for RPC function name, number of parameters, and name of parameters - derived from koiosapi.yaml on github
#  - [x] (External) Automate sync of koiosapi from alpha branch every 3 hours on monitoring instance
#  - [x] Remove loopback of failover (you do not want to mark yourself available, doing failover to remote instance if local struct does not match - redundant hop)
#        For previous iteration, if instance is DOWN but one of the peer is UP, haproxy would continue to mark instance as available making 2 additional hops within haproxy loop
#        The behaviour is logged on monitoring instance - so can be easily caught if abused, but more often than not would be done unintentionally
#  - [ ] Add check_endpt_post (parameters: [endpoint starting from /] [data to submit to POST request]
#  - [ ] Add updateCheck for grest-poll itself, checked hourly (or at first run post haproxy restart)
#  - [ ] Add interval to download spec URL and API_COMPARE
#  - [ ] Elect few endpoints that will indirectly test data
#        - Control Table (TODO: Version addition to Control Table)
#        - Query a sample from cache table (based on inputs from control table)
#        - We may not want to perform extensive dbsync data scan itself, except if bug/troublesome data on dbsync (eg: stake not being populated ~10 hours into epoch)
#  - [ ] If required and entire polling takes more than 3 seconds, Randomise some of the checks between the elected endpoints
#  - [ ] Add -d flag for debug mode - to run all tests without quitting
#

#TIP_DIFF=600                                                  # Maximum tolerance in seconds for tip to be apart before marking instance as not available to serve requests
#APIPATH=rpc                                                   # Default API path (without start/end slashes) to serve URL endpoints
#API_COMPARE="http://127.0.0.1:8050"                           # Source to be used for comparing RPC endpoint structure against. This variable only impacts failover "locally".
                                                               # Any changes here does not impact your nodes availability remotely, preventing loop of connections within proxies
#API_STRUCT_DEFINITION="https://api.koios.rest/koiosapi.yaml"  # The Doc URL that is to be considered as source of truth - only to be changed if not working with alpha branch

######################################
# Do NOT modify code below           #
######################################

function set_defaults() {
  [[ -z "${TIP_DIFF}" ]] && TIP_DIFF=600
  [[ -z "${APIPATH}" ]] && APIPATH=rpc
  [[ -z "${API_COMPARE}" ]] && API_COMPARE="http://127.0.0.1:8050"
  [[ -z "${API_STRUCT_DEFINITION}" ]] && API_STRUCT_DEFINITION="https://api.koios.rest/koiosapi.yaml"
  [[ "${HAPROXY_SERVER_NAME}" == *ssl ]] && SCHEME="https" || SCHEME="http"
  URL="${SCHEME}://${1}:${2}"
  URLRPC="${URL}/${APIPATH}"
}

function usage() {
  echo -e "\nUsage: $(basename "$0") <haproxy IP> <haproxy port> <server IP> <server port> [-d]\n"
  echo -e "Polling script used by haproxy to query server IP at server Port, and perform health checks. Use -d to run all health checks each time.\n\n"
  exit 1
}

function check_tip() {
  read -ra tip <<< "$(curl -skL "${URLRPC}/tip" 2>/dev/null | jq -r '[
    .[0].epoch // 0,
    .[0].abs_slot //0,
    .[0].epoch_slot //0,
    .[0].block_no //0,
    .[0].block_time // 0
  ] | @tsv' )"
  currtip=$(TZ='UTC' date "+%Y-%m-%d %H:%M:%S")
  dbtip=${tip[4]}
  if [[ -z "${dbtip}" ]] || [[ $(( $(date -d "${currtip}" +%s) - $(date -d "${dbtip}" +%s) )) -gt ${TIP_DIFF} ]] ; then
    echo "ERROR: ${URLRPC}/tip endpoint did not provide a timestamp that's within ${TIP_DIFF} seconds"
    echo "       Tip: ${currtip}, DB Tip: ${dbtip}, Difference: $(( $(date -d "${currtip}" +%s) - $(date -d "${dbtip}" +%s) ))"
    exit 1
  else
    epoch=${tip[0]}
    abs_slot=${tip[1]}
    epoch_slot=${tip[2]}
    block_no=${tip[3]}
  fi
}

function check_rpc_struct() {
  srvr_spec="$(curl -skL ${1} 2>/dev/null | jq 'leaf_paths | join(".")' )"
  api_endpts="$(curl -skL "${API_STRUCT_DEFINITION}" | grep ^\ \ / | sed -e 's#  /#/#g' -e 's#:##' | sort)"
  for endpt in ${api_endpts}
  do
    echo "${srvr_spec}" | grep -e "paths.*.${endpt}\\."
  done
}

function check_rpcs() {
  instance_rpc_cksum="$(check_rpc_struct ${URL} | sort | shasum -a 256)"
  monitor_rpc_cksum="$(check_rpc_struct ${API_COMPARE} | sort | shasum -a 256)"
  if [[ "${instance_rpc_cksum}" != "${monitor_rpc_cksum}" ]]; then
    echo "ERROR: The specs returned by ${URL} do not seem to match ${API_COMPARE} for endpoints mentioned at:"
    echo "  ${API_STRUCT_DEFINITION}"
    exit 1
  fi
}

function check_endpt_get() {
  local endpt=${1}
  [[ "${2}" != "rpc" ]] && urlendpt="${URL}/${endpt}" || urlendpt="${URLRPC}/${endpt}"
  getrslt=$(curl -skL "${urlendpt}" -H "Range: 0-1" 2>/dev/null)
  if [[ -z "${getrslt}" ]] || [[ "${getrslt}" == "[]" ]]; then
    echo "ERROR: Could not fetch from endpoint ${urlendpt} !!"
    exit 1
  fi
}

##################
# Main Execution #
##################

if [[ $# -lt 4 ]]; then
  usage
fi

set_defaults "$3" "$4"
check_tip

check_rpcs

check_endpt_get "genesis" view
check_endpt_get "blocks" view
check_endpt_get "tx_metalabels" view
check_endpt_get "account_list" view
check_endpt_get "totals?_epoch_no=${epoch}" rpc
check_endpt_get "epoch_params?_epoch_no=${epoch}" rpc
check_endpt_get "pool_list" rpc
