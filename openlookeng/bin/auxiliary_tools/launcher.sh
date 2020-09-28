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
shelldir=$(cd $(dirname $0); pwd)
source ${shelldir}/pathfile
declare COORDINATOR_IP=localhost
declare WORKER_NODES=localhost

function check_server()
{
    should_node_count=$1
    echo -n "waiting cluster to start..."
    i=0
    max_i=60
    while true
    do
        source /etc/profile
        source /home/openlkadmin/.*profile
        java  -jar $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-*-executable.jar  --server $COORDINATOR_IP:8090 --session "query_max_run_time=10s" --execute "select count(*) from system.runtime.nodes;" > /dev/null 2>&1
        #node=`echo ${nodes} | sed 's/\"//g'`
        ret=$?
        if [[ $ret == 0 ]]
        then
            node_count=`java  -jar $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-*-executable.jar  --server ${COORDINATOR_IP}:8090 --session "query_max_run_time=10s" --execute "select count(*) from system.runtime.nodes;"`
            node_count=${node_count:1}
            node_count=${node_count%*\"}
        fi
        if [[ $ret != 0 ]] || [[ $node_count != $should_node_count ]]
        then
            echo -n "."
            i=$i+1
            if [[ $i -ge $max_i ]]
            then
                echo -e "\n"
                return 1
            fi
            sleep 1
        else
            break
        fi
    done
    echo -e "\n"
}

function main()
{
    command=$1
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_node_config.sh false false
    if [[ -z $PASSLESS_NODES ]]
	then
		PASSLESS_NODES=$ALL_NODES
	fi
    local_ips=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
    local_ips_array=($local_ips)
    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    whoami=`whoami`
    for ip in ${host_array[@]}
    do
        echo "[INFO] $command openLooKeng service on $ip..."
        if [[ *" ${ip} "* == " ${local_ips_array[@]} " ]] || [[ "${ip}" == "localhost" ]]
        then
            line=`cat $INSTALL_PATH/hetu-server/etc/node.properties|grep node.launcher-log-file`
            IFS='=' read -ra keyvalue <<< "${line}"
            launcher="${keyvalue[1]}"
            line=`cat $INSTALL_PATH/hetu-server/etc/node.properties|grep node.server-log-file`
            IFS='=' read -ra keyvalue <<< "${line}"
            server="${keyvalue[1]}"
            if [[ "$whoami" == "openlkadmin" ]]
            then
                source /etc/profile
                source /home/openlkadmin/.*profile
                bash $INSTALL_PATH/hetu-server/bin/launcher --launcher-log-file=$launcher --server-log-file=$server $command &> /dev/null
            else
                su openlkadmin -c "source /etc/profile;source /home/openlkadmin/.*profile;bash $INSTALL_PATH/hetu-server/bin/launcher --launcher-log-file=$launcher --server-log-file=$server $command" &> /dev/null
            fi
        else
            if [[ "$whoami" == "openlkadmin" ]]
            then
                line=`ssh -o StrictHostKeyChecking=no openlkadmin@$ip "cat $INSTALL_PATH/hetu-server/etc/node.properties|grep node.launcher-log-file"`
                IFS='=' read -ra keyvalue <<< "${line}"
                launcher="${keyvalue[1]}"
                line=`ssh -o StrictHostKeyChecking=no openlkadmin@$ip "cat $INSTALL_PATH/hetu-server/etc/node.properties|grep node.server-log-file"`
                IFS='=' read -ra keyvalue <<< "${line}"
                server="${keyvalue[1]}"
                ssh -o StrictHostKeyChecking=no openlkadmin@$ip "source /etc/profile;source /home/openlkadmin/.*profile;bash $INSTALL_PATH/hetu-server/bin/launcher --launcher-log-file=$launcher --server-log-file=$server $command;exit" &> /dev/null
            else
                line=`su openlkadmin -c "ssh -o StrictHostKeyChecking=no openlkadmin@$ip \"cat $INSTALL_PATH/hetu-server/etc/node.properties|grep node.launcher-log-file\""`
                IFS='=' read -ra keyvalue <<< "${line}"
                launcher="${keyvalue[1]}"
                line=`su openlkadmin -c "ssh -o StrictHostKeyChecking=no openlkadmin@$ip \"cat $INSTALL_PATH/hetu-server/etc/node.properties|grep node.server-log-file\""`
                IFS='=' read -ra keyvalue <<< "${line}"
                server="${keyvalue[1]}"
                su openlkadmin &> /dev/null <<EOF
            ssh -o StrictHostKeyChecking=no openlkadmin@$ip "source /etc/profile;source /home/openlkadmin/.*profile;bash $INSTALL_PATH/hetu-server/bin/launcher --launcher-log-file=$launcher --server-log-file=$server $command;exit"
EOF
            fi
        fi
    done
    ret=$?
    IFS=',' read -ra all_array <<< "$ALL_NODES"
    if [[ "$command" == "start" ]] || [[ "$command" == "restart" ]]
    then
        check_server ${#all_array[@]}
        ret=$?
        echo "[INFO] You can see more details in $launcher and $server."
    #elif [[ $command == "stop" ]]
    #then
        #check_stop_status
    fi
    comm="$(tr '[:lower:]' '[:upper:]' <<< ${command:0:1})${command:1}"
    if [[ $ret == 0 ]]
    then
        echo "[INFO] ${comm}ed openLooKeng server success."
    else
        echo "[ERROR] ${comm}ed openLooKeng server failed."
        exit 1
    fi
}
main $@
