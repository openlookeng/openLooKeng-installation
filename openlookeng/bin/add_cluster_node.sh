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
declare local_ips_array=($local_ips)
export ISSINGLE=false
function print_help()
{
    cat <<EOF
         NAME
                add_cluster_node.sh - add nodes into cluster.
         USAGE
                bash add_cluster_node.sh [options [value]]

         OPTIONS
                -h,--help
                        print help message
                -n,--nodes <node_ips>
                        nodes need to add.
                -f,--file <file_path>
                        nodes need to add.
EOF
}
GETOPT_ARGS=`getopt -o :f:n:h -al file:,nodes:,help -- "$@"`
eval set -- "$GETOPT_ARGS"
function create_user()
{
    extend_ndodes="$1"
    IFS=',' read -ra host_array <<< "${extend_ndodes}"
    for ip in "${host_array[@]}"
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            bash $OPENLOOKENG_BIN_THIRD_PATH/hetu_adduser.sh
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OPENLOOKENG_BIN_THIRD_PATH/hetu_adduser.sh /opt
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "bash /opt/hetu_adduser.sh;rm -rf /opt/hetu_adduser.sh"
        fi
    done

}
function SshWithoutAuth(){
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/passwordless.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/passwordless.sh
}
function ask_passwd()
{
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/ask_password.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_password.sh
}
function java_check(){
    . $OPENLOOKENG_BIN_THIRD_PATH/env_check.sh --java
}
function install_server()
{
    whoami=`whoami`
    if [[ $whoami == openlkadmin ]]
    then
        hetu_server=`ssh openlkadmin@$COORDINATOR_IP "ls $INSTALL_PATH|grep hetu-server-"`
    else
        hetu_server=`sshpass -p $CLUSTER_PASS ssh $COORDINATOR_IP "ls $INSTALL_PATH|grep hetu-server-"`
    fi
    hetu_server=${hetu_server##*/}
    export openlk_version=${hetu_server##*-}
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/server_install.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/server_install.sh
}
function edit_node_config()
{
    res=`echo ${PASSLESS_NODES}|tr ' ' ','`
    if [[ -z $WORKER_NODES ]]
    then
        WORKER_NODES=$res
    else
        WORKER_NODES="${WORKER_NODES},${res}"
    fi
    if [[ ! -f $CLUSTER_NODE_INFO ]]
    then
        touch $CLUSTER_NODE_INFO
    fi
    echo -e "COORDINATOR_IP=$COORDINATOR_IP\nWORKER_NODES=$WORKER_NODES" > $CLUSTER_NODE_INFO
}
function change_user()
{
    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    for ip in "${host_array[@]}"
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            chown -R openlkadmin:openlkadmin $INSTALL_PATH
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "chown -R openlkadmin:openlkadmin $INSTALL_PATH"
        fi
    done
    chown -R openlkadmin:openlkadmin $OEPNLKADMIN_PATH
}
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
    IFS=',' read -ra extend_ndodes <<< "$parameter_node"
    extend_ndodes="${extend_ndodes[@]} ${file_nodes_arr[@]}"
    extend_ndodes=($(echo ${extend_ndodes[*]}|sed 's/ /\n/g'|sort|uniq))
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_node_config.sh false false
    if [[ -z ${extend_ndodes[*]} ]]
    then
        echo "[ERROR] No extended nodes,exiting now..."
        exit 1
    fi
    index=0
    for ip in ${extend_ndodes[@]}
    do
        bash ${OPENLOOKENG_BIN_THIRD_PATH}/ip_check.sh $ip
        if [[ $? != 0 ]]
        then
            echo "[WARN] $ip is an invalid ip, openLooKeng service will not be deployed on this node."
            unset extend_ndodes[$index]
        else
            including=`echo "$ALL_NODES"|grep "$ip"|wc -l`
            if [[ $including -gt 0 ]]
            then
                echo "[WARN] $ip has installed,openLooKeng service will not be deployed on this node again."
                unset extend_ndodes[$index]
            fi
        fi
        index=`expr $index + 1`
    done
    if [[ -z ${extend_ndodes[*]} ]]
    then
        echo "[ERROR] No valid nodes to extend,exiting now..."
        exit 1
    fi
    while true
    do
        read -r -p "Please confirm whether to extend the openLooKeng service to [${extend_ndodes[*]}][yes/no]?" RESPONSE
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
    export PASSLESS_NODES=`echo ${extend_ndodes[*]}|tr ' ' ','`
    ask_passwd
    create_user "${PASSLESS_NODES}"

    SshWithoutAuth
    java_check
    install_server
    export ISINSTALL=true
    . $OPENLOOKENG_BIN_THIRD_PATH/config_handle.sh
    edit_node_config
    change_user
    bash $OPENLOOKENG_BIN_PATH/start.sh
}
main $@