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
source ${shelldir}/auxiliary_tools/pathfile
declare ISDELETEUSER=false
declare SERVERONLY=false
declare CLUSTER_PASS
function ask_passwd()
{
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/ask_password.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_password.sh
}

function main()
{
    if [[ $# == 1 ]] || [[ $# == 2 ]]
    then
        if [[ $1 =~ "all" ]]
        then
            ISDELETEUSER=true
        elif [[ $1 =~ "serveronly" ]]
        then
            SERVERONLY=true
        fi
    fi
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_node_config.sh false false
    
    local_ips=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
    local_ips_array=($local_ips)
    if [[ -z ${PASSLESS_NODES[*]} ]]
    then
        PASSLESS_NODES=$ALL_NODES
    fi
    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    if [[ -z $CLUSTER_PASS ]]
    then
        ask_passwd
    fi
    #1.stop server     
    bash $OPENLOOKENG_BIN_PATH/stop.sh
  
    INCLUDING=false
    for ip in ${host_array[@]}
    do
        if [[ "${ip}" =~ "${local_ips_array[@]}" ]] || [[ "${ip}" == "localhost" ]]
        then
            INCLUDING=true
        else
            sshpass -p $CLUSTER_PASS ssh -o StrictHostKeyChecking=no root@$ip "rm -rf $INSTALL_PATH"
            if [[ $ISDELETEUSER == "true" ]]
            then
                sshpass -p $CLUSTER_PASS ssh -o StrictHostKeyChecking=no root@$ip "userdel -r openlkadmin;groupdel openlkadmin"
            fi
        fi
    done
    if [[ $INCLUDING == "true" ]]
    then
        if [[ $ISDELETEUSER == "true" ]]
        then
            userdel -r openlkadmin
            groupdel openlkadmin
        fi
        if [[ -d $INSTALL_PATH ]]
        then
            if [[ $SERVERONLY == true ]]
            then
                rm -rf $INSTALL_PATH/hetu-server-*
                rm -rf $INSTALL_PATH/hetu-server
            else
                rm -rf $INSTALL_PATH
            fi
        else
            echo "[WARN]OpenLooKeng service wasn't installed on local node."
        fi        
    fi
    if [[ $? == 0 ]] #&& [[ $SERVERONLY != "true" ]]
    then
        echo "[INFO] Uninstalled openLooKeng service successful."
    else
        echo "[INFO] Uninstalled openLooKeng service failed."
    fi
}
main $@