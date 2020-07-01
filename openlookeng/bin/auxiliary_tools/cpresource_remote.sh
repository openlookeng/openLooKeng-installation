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
function cpresource_remotenode(){
    full_path="${2}"
    node_ip="${1}"
    target_path="${3}"
    if [[ -z $CLUSTER_PASS ]]
    then
        whoami=`whoami`
        if [[ $whoami == "openlkadmin" ]]
        then
            scp -o StrictHostKeyChecking=no -r ${full_path} openlkadmin@$node_ip:$target_path &> /dev/null
        else
            su openlkadmin -c "scp -o StrictHostKeyChecking=no -r ${full_path} openlkadmin@$node_ip:$target_path" &> /dev/null
        fi
    else
        #scp
        sshpass -p $CLUSTER_PASS scp -o StrictHostKeyChecking=no -r $full_path $node_ip:$target_path &> /dev/null
    fi
}
cpresource_remotenode $@
