##
 # Copyright (C) 2018-2020. Huawei Technologies Co., Ltd. All rights reserved.
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 ##
#!/bin/bash
export wget_url=https://download.openlookeng.io
shelldir=$(cd $(dirname $0); pwd)
source ${shelldir}/auxiliary_tools/pathfile
declare local_ips=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
export local_ips_array=($local_ips)
function print_help()
{
    cat <<EOF
         NAME
                remove_cluster_node.sh - remove nodes from cluster.
         USAGE
                bash remove_cluster_node.sh [options [value]]

         OPTIONS
                -h,--help
                        print help message
                -n,--nodes <node_ips>
                        nodes need to remove.
                -f,--file <file_path>
                        nodes need to remove..
EOF
}
GETOPT_ARGS=`getopt -o :f:n:h -al file:,nodes:,help -- "$@"`
eval set -- "$GETOPT_ARGS"

function main()
{
    while [ -n "$1" ]
    do
        case "$1" in
                -h|--help)
                        print_help
                        exit 0;;
                -f|--file)
                        file_node=$2
                        shift 2;;
                -n|--nodes)
                        parameter_node=$2
                        shift 2;;
                --) shift ;;
                *) print_help;exit 1;break ;;
                esac
    done
    if [[ ! -z $file_node ]]
    then
        if [[ ! -f $file_node ]]
        then
            echo "[ERROR] $file_node is not exist."
            exit 1
        fi
        nodes_line=`cat $file_node`
        IFS=',' read -ra file_nodes_arr <<< "$nodes_line"
    fi
    IFS=',' read -ra remove_ndodes <<< "$parameter_node"
    remove_ndodes="${remove_ndodes[@]} ${file_nodes_arr[@]}"
    remove_ndodes=($(echo ${remove_ndodes[*]}|sed 's/ /\n/g'|sort|uniq))
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_node_config.sh false false
    if [[ -z ${remove_ndodes[*]} ]]
    then
        echo "[ERROR] No extended nodes,exiting now..."
        exit 1
    fi
    index=0
    for ip in ${remove_ndodes[@]}
    do
        bash ${OPENLOOKENG_BIN_THIRD_PATH}/ip_check.sh $ip
        if [[ $? != 0 ]]
        then
            echo "[WARN] $ip is an invalid ip."
            unset remove_ndodes[$index]
        else
            including=`echo "$ALL_NODES"|grep "$ip"|wc -l`
            if [[ $including -le 0 ]]
            then
                echo "[WARN] OpenLooKeng service hasn't been installed on $ip."
                unset remove_ndodes[$index]
            fi
        fi
        index=`expr $index + 1`
    done
    if [[ -z ${remove_ndodes[*]} ]]
    then
        echo "[ERROR] No valid nodes to remove,exiting now..."
        exit 1
    fi
    while true
    do
        read -r -p "Please confirm whether to remove ${remove_ndodes[*]} from cluster[yes/no]?" RESPONSE
        RESPONSE=`echo "$RESPONSE"|tr 'A-Z' 'a-z'`
        if [[ -z $RESPONSE ]] || [[ $RESPONSE == "y" ]] || [[ $RESPONSE == "yes" ]]
        then
            break
        elif [[ $RESPONSE == "n" ]] || [[ $RESPONSE == "no" ]]
        then
            echo "[INFO] Exiting now..."
            exit 1
        else
            echo "please input yes or no."
            continue
        fi
    done
    export PASSLESS_NODES=${remove_ndodes[*]}
    . $OPENLOOKENG_BIN_PATH/uninstall.sh --all
    IFS=',' read -ra host_array <<< "$WORKER_NODES"
    index=0
    for ip in ${host_array[@]}
    do
        including=`echo "${remove_ndodes[*]}"|grep "$ip"|wc -l`

        if [[ $COORDINATOR_IP == "$ip" ]]
        then
            unset COORDINATOR_IP
        fi
        if [[ $including -gt 0 ]]
        then
            unset host_array[$index]
        fi
        index=`expr $index + 1`
    done
    WORKER_NODES=`echo ${host_array[*]}|tr ' ' ','`
    if [[ ! -d $OEPNLKADMIN_PATH ]]
    then
        mkdir -p $OEPNLKADMIN_PATH
    fi
    if [[ ! -f $CLUSTER_NODE_INFO ]]
    then
        touch $CLUSTER_NODE_INFO
    fi
    echo -e "COORDINATOR_IP=$COORDINATOR_IP\nWORKER_NODES=$WORKER_NODES" > $CLUSTER_NODE_INFO
    chown -R openlkadmin:openlkadmin $OEPNLKADMIN_PATH
    echo "[INFO] Remove [${remove_ndodes[*]}] from cluster."
}
main $@