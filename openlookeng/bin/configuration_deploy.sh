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
whoami=`whoami`
function init_config_template()
{
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/config_handle.sh
    export ISINSTALL=false
    . $OPENLOOKENG_BIN_THIRD_PATH/config_handle.sh
}

function main()
{
    . $OPENLOOKENG_BIN_THIRD_PATH/ask_node_config.sh false false
	if [[ -z $PASSLESS_NODES ]]
	then
		PASSLESS_NODES=$ALL_NODES
	fi
    init_config_template
    if [[ $? == 0 ]]
    then
        echo "[INFO] Deploy Configuration successful."
        while true
        do
            read -r -p "The configuration will take effect after restart, whether to restart cluster now[yes/no]?" RESPONSE
            RESPONSE=`echo "$RESPONSE"|tr 'A-Z' 'a-z'`
            if [[ -z $RESPONSE ]] || [[ $RESPONSE == "y" ]] || [[ $RESPONSE == "yes" ]]
            then
                bash $OPENLOOKENG_BIN_PATH/restart.sh
                return $?
            elif [[ $RESPONSE == "n" ]] || [[ $RESPONSE == "no" ]]
            then
                 echo "[INFO] For the configuration to take effect, execute $OPENLOOKENG_BIN_PATH/restart.sh to restart the cluster"
                break
            else
                echo "please input yes or no."
                continue
            fi
        done
    else
        echo "[ERROR] Deploy Configuration failed."
    fi
}
main $@
retValue=$?
