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
export wget_url=https://download.openlookeng.io
declare openlk_version=
declare version_arr=
declare package_name=openlookeng.tar.gz
declare install_path=/opt/openlookeng
declare DEFAULT_MAX_SPLITS_PER_NODE_VALUE=100
declare DEFAULT_MAX_PENDING_SPLITS_PER_TASK_VALUE=10
declare CLUSTER_PASS
declare ISSINGLE=true
declare UPGRADE=false
declare COORDINATOR_IP=localhost
declare WORKER_NODES=localhost
declare ALL_NODES=localhost
declare TOTAL_MEM=`awk '/MemFree/ { printf "%d \n", $2/1024/1024 }' /proc/meminfo`
declare JVM_MEM=`echo $((TOTAL_MEM*70/100))`
declare local_ips=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
declare local_ips_array=($local_ips)
function print_help(){
    cat <<EOF
         NAME
                install.sh - Automatically install the specified version of openLooKeng.
         USAGE
                bash install_offline.sh [options [value]]

         OPTIONS
                -i <version_name>,--version <version_name>
                        optional, specify the openLooKeng version to install
                -l,--list
                        List all available version of openLooKeng to install
                -h,--help
                        print help message
                -m,--multi-node
                        install openLooKeng services to multi-node
                -s,--single-node
                        install openLooKeng services to Localhost only.
                -u,--upgrade <version_name>
                        upgrade openLooKeng specific version on all of nodes.
                -f,--file <file_path>
                        cluster node specific configuration file.
EOF
}

function print_versions(){
    echo "* openLooKeng versions:"
    echo "    ${version_arr[*]}"
}
function check_status()
{
    #check_serverstatus
    IFS=',' read -ra host_array <<< "${ALL_NODES}"

    for ip in "${host_array[@]}"
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            if [[ ! -d $INSTALL_PATH ]]
            then
                pcount=0
            else
                pcount=`ps -ef|grep HetuServer|grep "$INSTALL_PATH/hetu-server"|grep -v grep|wc -l`
            fi
        else
            if [[ ! -z $CLUSTER_PASS ]]
                then
                    pcount=`sshpass -p $CLUSTER_PASS ssh -oStrictHostKeyChecking=no root@$ip "ps -ef|grep HetuServer|grep '/opt/openLooKeng/hetu-server'|grep -v grep|wc -l"`
            else
                pcount=`su openlkadmin -c "ssh -o StrictHostKeyChecking=no openlkadmin@$ip \"ps -ef|grep HetuServer|grep '/opt/openLooKeng/hetu-server'|grep -v grep|wc -l\" "`
            fi
        fi
        if [[ $pcount > 0 ]]
        then
            arr[${#arr[*]}]=$ip
        fi
    done
    if [[ ${#arr[@]} > 0 ]]
    then
        while true
        do
            read -r -p "It is found that the openLooKeng service is running on ${arr[*]}. Continue to install will cause the service to stop and uninstall. Do you want to continue[yes/no]?" RESPONSE
            RESPONSE=`echo "$RESPONSE"|tr 'A-Z' 'a-z'`
            if [[ -z $RESPONSE ]] || [[ $RESPONSE == "y" ]] || [[ $RESPONSE == "yes" ]]
            then
                if [[ $UPGRADE == true ]]
                then
                #bakup etc and catalog
                    bakup
                    if [[ $? != 0 ]]
                    then
                        exit 1
                    fi
                fi
                bash $OPENLOOKENG_BIN_PATH/uninstall.sh --serveronly
                break
            elif [[ $RESPONSE == "n" ]] || [[ $RESPONSE == "no" ]]
            then
                echo "[INFO] Exiting now..."
                exit 1
            else
                echo "please input yes or no."
                continue
            fi
        done
    else
        #check_installation
        check_installation
    fi

}
function check_installation()
{
    IFS=',' read -ra host_array <<< "${ALL_NODES}"

    for ip in "${host_array[@]}"
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            if [[ ! -d $INSTALL_PATH ]]
            then
                pcount=0;
            else
                pcount=`ls $INSTALL_PATH|grep hetu-server|grep -v grep|wc -l`
            fi
        else
            su openlkadmin &>/dev/null <<EOF
        ssh -o StrictHostKeyChecking=no openlkadmin@$ip "ls $INSTALL_PATH"
EOF
            if [[ $? == 0 ]]
            then
                if [[ ! -z $CLUSTER_PASS ]]
                then
                    pcount=`sshpass -p $CLUSTER_PASS ssh -oStrictHostKeyChecking=no root@$ip "ls $INSTALL_PATH|grep hetu-server|grep -v grep|wc -l"`
                else
                    pcount=`su openlkadmin -c "ssh -o StrictHostKeyChecking=no openlkadmin@$ip \"ls $INSTALL_PATH|grep hetu-server|grep -v grep|wc -l\" "`
                fi
            else
                pcount=0
            fi
        fi
        if [[ $pcount > 0 ]]
        then
            array[${#array[*]}]=$ip
        fi
    done

        if [[ $pcount > 0 ]]
        then
            while true
            do
                read -r -p "It is found that the openLooKeng service has been installed on ${array[*]}. If it continues, it will be automatically uninstalled first. Do you want to continue[yes/no]?" RESPONSE
                RESPONSE=`echo "$RESPONSE"|tr 'A-Z' 'a-z'`
                if [[ -z $RESPONSE ]] || [[ $RESPONSE == "y" ]] || [[ $RESPONSE == "yes" ]]
                then
                    if [[ $UPGRADE == true ]]
                    then
                #bakup etc and catalog
                        bakup
                        if [[ $? != 0 ]]
                        then
                            exit 1
                        fi
                    fi
                    bash $OPENLOOKENG_BIN_PATH/uninstall.sh --serveronly
                    break
                elif [[ $RESPONSE == "n" ]] || [[ $RESPONSE == "no" ]]
                then
                    echo "[INFO] Exiting now..."
                    exit 1
                else
                    echo "please input yes or no."
                    continue
                fi
            done
        fi

}
function check_serverstatus()
{
    echo "Abandoned"
}
function config_cluster()
{
   . $OPENLOOKENG_BIN_THIRD_PATH/ask_node_config.sh $ISSINGLE true
}

function ask_passwd()
{
    if [[ $ISSINGLE != true ]]
    then
        chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/ask_password.sh
        . $OPENLOOKENG_BIN_THIRD_PATH/ask_password.sh
    fi
}
function install()
{
    #9.check and install jdk-8u201-linux-x64
    java_check
    if [[ $? != 0 ]]
    then
        return 1
    fi
    #10 check mem
    memory_check
    if [[ $? != 0 ]]
    then
        return 1
    fi
    #install openLooKeng server
    install_server
    if [[ $? != 0 ]]
    then
        return 1
    fi
    #init config
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/config_handle.sh
    export ISINSTALL=true
    export UPGRADE
    . $OPENLOOKENG_BIN_THIRD_PATH/config_handle.sh

    change_user
}
function SshWithoutAuth(){
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/passwordless.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/passwordless.sh
}

function change_user()
{
    IFS=',' read -ra host_array <<< "${ALL_NODES}"
    for ip in "${host_array[@]}"
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            chown -R openlkadmin:openlkadmin $INSTALL_PATH
			      chmod -R 755 $INSTALL_PATH/hetu-server/bin
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "chown -R openlkadmin:openlkadmin $INSTALL_PATH;chmod -R 755 $INSTALL_PATH/hetu-server/bin"
        fi
    done
    chown -R openlkadmin:openlkadmin $OEPNLKADMIN_PATH
}

function install_server()
{
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/server_install.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/server_install.sh offline
}
function create_user()
{
    #if [[ "$ISSINGLE" == "true" ]]
    #then
    #    bash $OPENLOOKENG_BIN_THIRD_PATH/hetu_adduser.sh
    #    return $?
    #fi
    IFS=',' read -ra host_array <<< "${ALL_NODES}"
    for ip in "${host_array[@]}"
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            #bash $OPENLOOKENG_BIN_THIRD_PATH/hetu_adduser.sh # will create user before
            continue
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OPENLOOKENG_BIN_THIRD_PATH/hetu_adduser.sh /opt
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "bash /opt/hetu_adduser.sh;rm -rf /opt/hetu_adduser.sh"
        fi
    done

}
function java_check(){
    . $OPENLOOKENG_BIN_THIRD_PATH/env_check.sh --java offline
}
function memory_check()
{
    . $OPENLOOKENG_BIN_THIRD_PATH/env_check.sh --memory
}

function check_node_reachable(){
    . $OPENLOOKENG_BIN_THIRD_PATH/env_check.sh --reachable
}

function env_check()
{
    . $OPENLOOKENG_BIN_THIRD_PATH/env_check.sh --sshpass offline
    if [[ $? != 0 ]]
    then
        exit 1
    fi

    . $OPENLOOKENG_BIN_THIRD_PATH/env_check.sh --cli offline
    if [[ $? != 0 ]]
    then
        exit 1
    fi
}
function bakup()
{
    chmod u+x $OPENLOOKENG_BIN_THIRD_PATH/bakup.sh
    . $OPENLOOKENG_BIN_THIRD_PATH/bakup.sh
}
function check_file()
{
    file_path=$1
    if [[ -z $file_path ]]
    then
        echo "[ERROR] The full path of the file needs to be specified."
        exit 1
    fi
    if [[ ! -f $file_path ]]
    then
        echo "[ERROR] $file_path doesn't exist."
        exit 1
    fi
    unset COORDINATOR_IP
    unset WORKER_NODES
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
    done < $file_path
    if [[ -z $COORDINATOR_IP ]] || [[ -z $WORKER_NODES ]]
    then
        echo "[ERROR] Incorrect configuration file format."
        exit 1
    fi
    isWorker=`echo ${WORKER_NODES}|grep $COORDINATOR_IP`
    if [[ -z $isWorker ]]
    then
            ALL_NODES="$COORDINATOR_IP,${WORKER_NODES}"
    else
            ALL_NODES="${WORKER_NODES}"
    fi
    IFS=',' read -ra nodes <<< "${ALL_NODES}"
    for node in "${nodes[@]}"
    do
        bash ${OPENLOOKENG_BIN_THIRD_PATH}/ip_check.sh $node
        if [[ $? != 0 ]]
        then
            invalid_nodes="$invalid_nodes $node "
        fi
    done
    if [[ ! -z "$invalid_nodes" ]]
    then
        echo "[ERROR] $invalid_nodes is/are not valid IP."
        exit 1
    fi
    #echo "$COORDINATOR_IP----$WORKER_NODES----"
    #exit 1
}

function read_versions()
{
    mapfile -t version_arr < <(find $install_path/resource/ -name "hetu-server-*" | egrep -o '010|[0-9]+\.[0-9]+\.[0-9]+' | sort -u)

    if [[ -z $openlk_version ]]
    then
        openlk_version=${version_arr[-1]}
    fi
}

function check_version()
{
    version="$1"
    for v in ${version_arr[@]}
    do
        if [[ "$v" == "$version" ]]
        then
            return 0
        fi
    done
    return 1
}

GETOPT_ARGS=`getopt -o :u:hli:msf: -al :upgrade:,help,list,version:,multi-node,single-node,file: -- "$@"`
eval set -- "$GETOPT_ARGS"
function main()
{
    while [ -n "$1" ]
    do
        case "$1" in
                -h|--help)
                        print_help
                        exit 0;;
                -l|--list)
                        print_versions
                        exit 0;;
                -i|--version)
                        openlk_version="$2"
                        shift 2;;
                -m|--multi-node)
                        ISSINGLE=false
                        #echo "not support now"
                        #exit 1
                        shift ;;
                -s|--single-node)
                        ISSINGLE=true
                        shift ;;
                -u|--upgrade)
                        ISSINGLE=false
                        openlk_version="$2"
                        UPGRADE=true
                        shift 2;;
                -f|--file)
                        ISSINGLE=false
                        file_path=$2
                        check_file $file_path
                        shift 2;;
                --) shift ;;
                *) print_help;exit 1;break ;;
                esac
    done

    read_versions
    check_version $openlk_version
        if [[ $? != 0 ]]
        then
          echo "[ERROR] Incorrect version."
          print_versions
          exit 1
        fi

    #shelldir=$(cd $(dirname $0); pwd)
    #cd $shelldir
    cd `pwd`

    #3.source pathfile
    source $install_path/bin/auxiliary_tools/pathfile

    echo "source $install_path/bin/auxiliary_tools/pathfile"
    #4.create user on local node
    bash $OPENLOOKENG_BIN_THIRD_PATH/hetu_adduser.sh
    if [[ $? != 0 ]]
    then
        return 1
    fi
    if [[ ! -z $file_path ]]
    then
        if [[ ! -d $OEPNLKADMIN_PATH ]]
        then
            mkdir -p $OEPNLKADMIN_PATH
        fi
        echo "[INFO] Copy $file_path to $CLUSTER_NODE_INFO."
        cp $file_path $CLUSTER_NODE_INFO
        if [[ $? != 0 ]]
        then
            return 1
        fi
    fi
    if [[ $ISSINGLE != "true" ]]
    then
        env_check
        if [[ $? != 0 ]]
        then
            return 1
        fi
    fi
    #5.config cluster
    config_cluster
    if [[ $? != 0 ]]
    then
        return 1
    fi
    export PASSLESS_NODES=${ALL_NODES}
    check_node_reachable
    #6.ask for root pass
    ask_passwd
    if [[ $? != 0 ]]
    then
        return 1
    fi
    if [[ "$ISSINGLE" != "true" ]]
    then

        if [[ $UPGRADE == false ]]
        then
            #7.create openlkadmin user
            create_user
            if [[ $? != 0 ]]
            then
                return 1
            fi
            #8.passwd less
            SshWithoutAuth
            if [[ $? != 0 ]]
            then
                return 1
            fi
        fi
    fi
    check_status
    if [[ $? != 0 ]]
    then
        return 1
    fi

    install
    if [[ $? != 0 ]]
    then
        echo "[ERROR] OpenLooKeng installation failed."
        exit 1
    fi
    echo "[INFO] Installed openLooKeng cluster success. "
    echo "[INFO] Starting openLooKeng service now... "
    bash $OPENLOOKENG_BIN_PATH/start.sh
    ret=$?
    if [[ $ret == 0 ]]
    then
        echo "[INFO] Execute $OPENLOOKENG_BIN_PATH/stop.sh by user 'openlkadmin', to stop openLooKeng cluster."
        echo "[INFO] Execute $OPENLOOKENG_BIN_PATH/openlk-cli, to start openLooKeng client."
    fi
}
main $@
retValue=$?
exit ${retValue}
