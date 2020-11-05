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
declare architecture=x86
res=`arch|grep x86|wc -l`
if [[  $res > 0 ]]
then
    architecture=x86
else
    architecture=aarch64
fi
export resource_url_base=$wget_url/auto-install/third-resource
export resource_url=$wget_url/auto-install/third-resource/$architecture
export architecture
function check_sshpass()
{
    curl --max-time 10 -IL $wget_url &> /dev/null
    offline=$1
    echo "[INFO] Checking sshpass installation..."
    ret_str=`sshpass |awk -F':' '{print $1}' |sed -n '1p'`
    if [[ "${ret_str}" == "Usage" ]]
    then
        echo "[INFO] sshpass is already installed."
        return 0
    fi
    echo "[INFO] Sshpass is not installed. Start to install it right now..."
    if [[ -z $offline ]]
    then
        curl -fsSL -o /opt/sshpass-1.06.tar.gz $resource_url/sshpass-1.06.tar.gz
        if [[ $architecture == "x86" ]]
        then
            curl -fsSL -o /opt/sshpass-1.06-2.el7.x86_64.rpm $resource_url/sshpass-1.06-2.el7.x86_64.rpm
        else
            curl -fsSL -o /opt/sshpass-1.06-2.el7.x86_64.rpm $resource_url/sshpass-1.06-1.el7.aarch64.rpm
        fi
    else
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06.tar.gz ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06.tar.gz doesn't exist."
            return 1
        fi
        if [[ $architecture == "x86" ]] && [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-2.el7.x86_64.rpm ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-2.el7.x86_64.rpm doesn't exist."
            return 1
        fi
        if [[ $architecture != "x86" ]] && [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-1.el7.aarch64.rpm ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-1.el7.aarch64.rpm doesn't exist."
            return 1
        fi
        cp $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06.tar.gz /opt
        if [[ $architecture == "x86" ]]
        then
            cp $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-2.el7.x86_64.rpm /opt
        else
            cp $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-1.el7.aarch64.rpm /opt
        fi
    fi
    gcc_str=`gcc -v 2>&1 |awk 'NR==1{ gsub(/"/,""); print $1 }'`
    if [[ "${gcc_str}" == "Using" ]]
    then
        tar -zxvf /opt/sshpass-1.06.tar.gz -C /opt>/dev/null 2>&1
        cd /opt/sshpass-1.06 >/dev/null 2>&1
        ./configure >/dev/null 2>&1
        make >/dev/null 2>&1
        make install >/dev/null 2>&1
        cd - >/dev/null 2>&1
    else
        if [[ $architecture == "x86" ]]
        then
            rpm -ivh /opt/sshpass-1.06-2.el7.x86_64.rpm >/dev/null 2>&1
        else
            rpm -ivh /opt/sshpass-1.06-1.el7.aarch64.rpm >/dev/null 2>&1
        fi
    fi
    ret_str=`sshpass |awk -F':' '{print $1}' |sed -n '1p'`
    if [[ "${ret_str}" == "Usage" ]]
    then
        echo  "[INFO] sshpass install succeeded."
    else
        echo "[ERROR] sshpass install failed."
        return 1
    fi

}

function java_install_check(){
    offline=$1

    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    for ip in ${host_array[@]}
    do
        echo "[INFO] Check jdk installation on $ip..."
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            bash $OPENLOOKENG_BIN_THIRD_PATH/install_java.sh $offline $resource_url_base
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OPENLOOKENG_BIN_THIRD_PATH/install_java.sh /opt
            remote_arch=$(. $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip 'res=`arch|grep x86|wc -l`; if [[  $res > 0 ]]; then echo x86; else echo aarch64; fi')
            if [[ ! -z $offline ]]
            then
                if [[ $remote_arch == $architecture ]]
                then
                    . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OPENLOOKENG_DEPENDENCIES_PATH/OpenJDK8U-jdk* /opt
                else
                    . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OPENLOOKENG_DEPENDENCIES_PATH/$remote_arch/OpenJDK8U-jdk* /opt
                fi
            fi
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "bash /opt/install_java.sh $offline $resource_url_base; rm -f /opt/install_java.sh;exit"
        fi
    done
}
function memory_check()
{
    if [[ $JVM_MEM -lt 4 ]]
    then
        echo "[ERROR] There is not enough memory for openLooKeng to install. OpenLooKeng requires more than 4GB JVM memory."
        return 1
    fi
}
function check_node_reachable()
{
    if [[ ! -z $ALL_NODES ]]
    then
        IFS=',' read -ra host_array <<< "${ALL_NODES}"
        for ip in "${host_array[@]}"
        do
            if [[ " ${local_ips_array[@]} " != *" ${ip} "*  ]] && [[ "${ip}" != "localhost" ]] ; then
                ping -c3 -W3 ${ip}  >/dev/null 2>&1
                if [ $? -eq 0 ]
                then
                    echo "[INFO] The IP address: ${ip} can be reachable"
                else
                    echo "[ERROR] The IP address: ${ip} can not be reachable"
                    return 1
                fi
            fi
        done
    fi
}
function download_cli()
{
    offline=$1
    if [[ ! -d $OPENLOOKENG_DEPENDENCIES_PATH ]]
    then
        mkdir -p $OPENLOOKENG_DEPENDENCIES_PATH
    fi
    if [[ -z $offline ]]
    then
        curl -fsSL -o $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar $wget_url/$openlk_version/hetu-cli-$openlk_version-executable.jar
        if [[ $? == 0 ]]
        then
            chmod u+x $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar
        else
            echo "[ERROR] DownLoad openLooKeng client failed."
            return 1
        fi
    else
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar ]]
        then
            echo "[ERROR] OpenLooKeng client didn't found."
            return 1
        else
            chmod u+x $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar
        fi
    fi
}

function main()
{
    offline=$2
    if [[ $1 =~ "sshpass" ]]
    then
        check_sshpass $offline
        return $?
    fi
    if [[ $1 =~ "java" ]]
    then
        java_install_check $offline
        return $?
    fi
    if [[ $1 =~ "memory" ]]
    then
        memory_check
        return $?
    fi
    if [[ $1 =~ "reachable" ]]
    then
        check_node_reachable
        return $?
    fi

    if [[ $1 =~ "cli" ]]
    then
        download_cli $offline
        return $?
    fi
}
main $@
