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
function SshKeyGen()
{
    if [[ -f /home/openlkadmin/.ssh/id_rsa ]]
    then
        #rm -f /home/openlkadmin/.ssh/id_rsa
        #rm -f /home/openlkadmin/.ssh/id_rsa.pub
        return 0
    fi
    whoami=`whoami`
    if [[ "$whoami" == "openlkadmin" ]]
    then
        ssh-keygen -t rsa -f /home/openlkadmin/.ssh/id_rsa  -P ""
    else
        su openlkadmin -c "ssh-keygen -t rsa -f /home/openlkadmin/.ssh/id_rsa  -P \"\""
    fi
}
function SshWithoutAuth(){
    SshKeyGen
    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    for host in "${host_array[@]}"
    do
            var=$(cat /home/openlkadmin/.ssh/id_rsa.pub) &> /dev/null
            command="mkdir -p /home/openlkadmin/.ssh;echo $var >> /home/openlkadmin/.ssh/authorized_keys;chown openlkadmin:openlkadmin /home/openlkadmin/.ssh/authorized_keys;chmod 600 /home/openlkadmin/.ssh/authorized_keys;exit;"
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh "${host}" "${command}"
    done
}
SshWithoutAuth $@
