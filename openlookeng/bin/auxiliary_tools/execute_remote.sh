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
function execute_remotenode()
{        
        command=`echo ${@:2}`
        node_ip=$1
        if [[ -z $CLUSTER_PASS ]]
        then
            whoami=`whoami`
            if [[ $whoami == "openlkadmin" ]]
            then
                ssh -o StrictHostKeyChecking=no openlkadmin@$node_ip "$command"
            else
                su openlkadmin -c "ssh -o StrictHostKeyChecking=no openlkadmin@$node_ip \"$command\""
            fi
        else
            #ssh
            sshpass -p $CLUSTER_PASS ssh -oStrictHostKeyChecking=no root@$node_ip "$command"
        fi
}
execute_remotenode $@
