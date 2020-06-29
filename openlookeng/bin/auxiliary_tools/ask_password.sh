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
function check_password()
{
    ip=$1
    cluster_pass=$2
    echo "[INFO] Verifying cluster password..."
    sshpass -p $cluster_pass ssh -oStrictHostKeyChecking=no root@${ip} "hostname"
    ret=$?
    if [ ${ret} -ne 0 ]
    then
        echo "[ERROR] The password provided is incorrect for ${ip}, return code is: ${ret}"
        return 1
    fi
}
function ask_passwd()
{
    for((i=1; i<=3;i++))
    do
        read -s -p "Enter your cluster's password for root user:" passwd
        check_password ${COORDINATOR_IP} ${passwd}
        if [ $? -ne 0 ]
        then
            if [ ${i} == 3 ]
            then
                echo "[ERROR] The maximum number of login attempts has been reached. Please try again later. Exit now ..."
                exit 1
            else
                echo "[ERROR] Your username or password is not correct, please try again."
                continue
            fi
        else
            break
        fi
    done
    export CLUSTER_PASS=${passwd}
}
ask_passwd $@