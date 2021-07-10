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
function adduser()
{
    # whether openlkadmin exit,create openlkadmin
    result=`egrep '^openlkadmin:' /etc/group | wc -l`
    if [[ $result == 0 ]]
    then
        groupadd openlkadmin &> /dev/null
        if [[ $? != 0 ]]
        then
            exit 1
        fi
    fi
    result=`egrep '^openlkadmin:' /etc/passwd | wc -l`
    if [[ $result == 0 ]]
    then
        echo "[INFO] Create user openlkadmin."
        useradd -m -g openlkadmin openlkadmin &> /dev/null
        if [[ $? != 0 ]]
        then
            exit 1
        fi
    else
        #pgrep -u openlkadmin | sudo xargs kill -9 &> /dev/null
        usermod -g openlkadmin openlkadmin &> /dev/null
    fi
    #pgrep -u openlkadmin | sudo xargs kill -9 &> /dev/null
    chown -R openlkadmin:openlkadmin /home/openlkadmin
    #grep -n "openlkadmin" /etc/sudoers
    #if [[ $? != 0 ]] ##bigger than 1.2
    #then
#        sed '$aopenlkadmin ALL = NOPASSWD: ALL' /etc/sudoers
#    fi
    return $?
}
function main()
{
    adduser
}
main $@
retValue=$?
exit ${retValue}