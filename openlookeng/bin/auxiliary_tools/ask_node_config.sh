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
#source ${shelldir}/pathfile

function config_cluster()
{
    if [[ "$ISSINGLE" == "true" ]]
    then
        COORDINATOR_IP=localhost
        WORKER_NODES=localhost
    else
        while true
        do
            while true
            do
                read -r -p "Enter IP address of coordinator node:" COORDINATOR_IP
                bash ${OPENLOOKENG_BIN_THIRD_PATH}/ip_check.sh $COORDINATOR_IP
                if [[ $? == 0 ]]
                then
                    break
                else
                    echo "[ERROR] $COORDINATOR_IP  is not a valid ip address."
                fi
            done
            while true
            do
                read -r -p "Enter IP addresses of worker nodes, separated by commas(,):" WORKER_NODES
                IFS=',' read -ra worker_array <<< "${WORKER_NODES}"
                for node in "${worker_array[@]}"
                do
                    bash ${OPENLOOKENG_BIN_THIRD_PATH}/ip_check.sh $node
                    if [[ $? != 0 ]]
                    then
                        invalid_nodes="$invalid_nodes $node "
                    fi
                done
                if [[ -z "$invalid_nodes" ]]
                then
                    break
                else 
                    echo "[ERROR] $invalid_nodes is/are not valid IP."
                fi
            done        
            echo "[INFO] Coordinator is $COORDINATOR_IP ... "
            echo "[INFO] Workers are $WORKER_NODES ... "
            while true
            do
                read -r -p "Please confirm whether to deploy the openLooKeng service to the above nodes[yes/no]?" RESPONSE
                RESPONSE=`echo "$RESPONSE"|tr 'A-Z' 'a-z'`
                if [[ -z $RESPONSE ]] || [[ $RESPONSE == "y" ]] || [[ $RESPONSE == "yes" ]]
                then
                    break 2
                elif [[ $RESPONSE == "n" ]] || [[ $RESPONSE == "no" ]]
                then
                    continue 2
                else
                    echo "please input yes or no."
                    continue
                fi
            done
        done
        echo "[INFO] Stored cluster node info into $CLUSTER_NODE_INFO"
        
    fi
    if [[ ! -f $CLUSTER_NODE_INFO ]]
    then
        su openlkadmin -c "mkdir -p $OEPNLKADMIN_PATH;touch $CLUSTER_NODE_INFO"
    fi
    echo -e "COORDINATOR_IP=$COORDINATOR_IP\nWORKER_NODES=$WORKER_NODES" > $CLUSTER_NODE_INFO
}
function read_config()
{
    while read line;
    do
        prop="$(cut -d '=' -f1 <<< $line)"
        val="$(cut -d '=' -f2 <<< $line)"
        case $prop in
            "COORDINATOR_IP")
                COORDINATOR_IP=$val
                ;;
            "WORKER_NODES")
                WORKER_NODES=$val
                ;;
        *)
        esac
    done < $CLUSTER_NODE_INFO
}
function main()
{
    #1 is singlenode  ,2 is ask confirm again
    if [[ $# -ne 2 ]]
    then
        exit 1
    fi
    if [[ "$1" != "true" ]] && [[ "$1" != "false" ]]
    then
        exit 1
    fi
    if [[ "$2" != "true" ]] && [[ "$2" != "false" ]]
    then
        exit 1
    fi
    if [[ ! -f $CLUSTER_NODE_INFO ]]
    then
        config_cluster $1
    else        
        if [[ ${1} != "true" && ${2} == true ]] # 2nd para is ask confirm
        then
            echo "[INFO] Reading cluster node info from $CLUSTER_NODE_INFO"
            read_config
            echo "[INFO] Coordinator is $COORDINATOR_IP ... "
            echo "[INFO] Workers are $WORKER_NODES ... "
            while true
            do
                read -r -p "Do you want to deploy openLooKeng service to these nodes[yes/no]?" RESPONSE
                RESPONSE=`echo "$RESPONSE"|tr 'A-Z' 'a-z'`
                if [[ -z $RESPONSE ]] || [[ $RESPONSE == "y" ]] || [[ $RESPONSE == "yes" ]]
                then
                    echo -e "COORDINATOR_IP=$COORDINATOR_IP\nWORKER_NODES=$WORKER_NODES" > $CLUSTER_NODE_INFO
                    break
                elif [[ $RESPONSE == "n" ]] || [[ $RESPONSE == "no" ]]
                then
                    config_cluster $1
                    break
                else
                    echo "please input yes or no."
                    continue
                fi
            done        
        fi
    fi
    if [[ $ISSINGLE == "true" ]]
    then
        COORDINATOR_IP=localhost
        WORKER_NODES=localhost
        echo -e "COORDINATOR_IP=$COORDINATOR_IP\nWORKER_NODES=$WORKER_NODES" > $CLUSTER_NODE_INFO
    else
        read_config
    fi
    isWorker=`echo ${WORKER_NODES}|grep $COORDINATOR_IP`
    if [[ -z $isWorker ]]
    then
            ALL_NODES="$COORDINATOR_IP,${WORKER_NODES}"
    else
            ALL_NODES="${WORKER_NODES}"
    fi
    export COORDINATOR_IP WORKER_NODES ALL_NODES
}
main $@
#retValue=$?
#exit $retValue