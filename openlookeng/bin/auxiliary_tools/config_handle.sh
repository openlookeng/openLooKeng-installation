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
function init_config_template()
{

    if [[ ! -d $OEPNLKADMIN_PATH/.etc_template ]]
    then
        #rm -rf $OEPNLKADMIN_PATH/.etc_template
        if [[ ! -d $INSTALL_PATH/etc_template ]]
        then
            echo "[ERROR] Some etc_template files lost."
            exit 1
        else
            mv $INSTALL_PATH/etc_template $OEPNLKADMIN_PATH/.etc_template
        fi
    else
        rm -rf $INSTALL_PATH/etc_template
    fi

    #if [[ ! -f $OEPNLKADMIN_PATH/.etc_template/cluster_config_info ]]
    #then
        #echo "[ERROR]File in etc_template was lost."
        #exit 1
    #fi
    #mv $OEPNLKADMIN_PATH/.etc_template/cluster_config_info  $OEPNLKADMIN_PATH
    if [[ -d $OEPNLKADMIN_PATH/.etc ]]
    then
        rm -rf $OEPNLKADMIN_PATH/.etc
    fi
    cp -r $OEPNLKADMIN_PATH/.etc_template $OEPNLKADMIN_PATH/.etc
    if [[ ! -f $OEPNLKADMIN_PATH/cluster_config_info ]]
    then
        IFS=',' read -ra host_array <<< "$WORKER_NODES"
        NUM_WORKERS=${#host_array[@]}
        NUM_CPU=`grep -c ^processor /proc/cpuinfo`
        MAX_MEM_PER_NODE=`echo $((JVM_MEM*25/100))`
        MAX_MEM=`echo $((JVM_MEM*NUM_WORKERS*25/100))`
        MAX_TOTAL_MEM=`echo $((JVM_MEM*NUM_WORKERS*25/100))`
        MAX_TOTAL_MEM_PER_NODE=` echo $((JVM_MEM*25/100))`
        MAX_WORKER_THREADS=`echo $((NUM_CPU*2))`
        HEAP_HEADRM=`echo $((JVM_MEM*25/100))`
        EXCHANGE_CLIENT_THREADS=`echo $((NUM_CPU*50/100))`
        MAX_SPLITS_PER_NODE=$DEFAULT_MAX_SPLITS_PER_NODE_VALUE
        MAX_PENDING_SPLITS_PER_TASK=$DEFAULT_MAX_PENDING_SPLITS_PER_TASK_VALUE
        case 1:${NUM_CPU:--} in
            (1:*[!0-9]*|1:0*[89]*)
            ! echo NAN
            ;;
            ($((NUM_CPU<8))*)
                #echo "NUM_CPU >=0<=8"
                TASK_CONCURRENCY=2
            ;;
            ($((NUM_CPU<16))*)
                #echo "NUM_CPU >=8<=16"
                TASK_CONCURRENCY=8
            ;;
            ($((NUM_CPU<32))*)
                #echo "NUM_CPU >=16<=32"
                TASK_CONCURRENCY=16
            ;;
            ($((NUM_CPU<64))*)
                #echo "NUM_CPU >=32<=64"
                TASK_CONCURRENCY=32
            ;;
            ($((NUM_CPU<128))*)
                #echo "NUM_CPU >=64<=128"
                TASK_CONCURRENCY=64
            ;;
            ($((NUM_CPU<256))*)
                #echo "NUM_CPU >=128<=256"
                TASK_CONCURRENCY=128
            ;;
            ($((NUM_CPU<512))*)
                #echo "NUM_CPU >=256<=512"
                TASK_CONCURRENCY=256
            ;;
            ($((NUM_CPU>512))*)
                #echo "NUM_CPU >=512"
                TASK_CONCURRENCY=512
            ;;
            esac
        isWorker=`echo ${WORKER_NODES}|grep $COORDINATOR_IP`
        if [[ -z $isWorker ]]
        then
            CN_as_WORKER=false
        else
            CN_as_WORKER=true
        fi
        IFS=',' read -ra nodes_for_count <<< "$ALL_NODES"
        if [[ ${#nodes_for_count[@]} == 1 ]]
        then
            CN_as_WORKER=true
        fi
        cluster_config_info="jvm_memory=$JVM_MEM\nnode-scheduler.include-coordinator=$CN_as_WORKER\nhttp-server.http.port=8090\nexchange.client-threads=${EXCHANGE_CLIENT_THREADS}\ntask.max-worker-threads=${MAX_WORKER_THREADS}\nquery.max-memory=${MAX_MEM}GB\nquery.max-total-memory=${MAX_TOTAL_MEM}GB\nquery.max-memory-per-node=${MAX_MEM_PER_NODE}GB\nquery.max-total-memory-per-node=${MAX_TOTAL_MEM_PER_NODE}GB\nexperimental.spill-enabled=false\nexperimental.spiller-spill-path=${INSTALL_PATH}/sqlengine_path\nmemory.heap-headroom-per-node=${HEAP_HEADRM}GB\ntask.concurrency=${TASK_CONCURRENCY}\nnode-scheduler.max-splits-per-node=200\nnode-scheduler.max-pending-splits-per-task=20\nexperimental.reserved-pool-enabled=false\nquery.low-memory-killer.policy=total-reservation-on-blocked-nodes\nexperimental.max-spill-per-node=${DEFAULT_MAX_SPLITS_PER_NODE_VALUE}GB\nexperimental.query-max-spill-per-node=${DEFAULT_MAX_PENDING_SPLITS_PER_TASK_VALUE}GB"
        touch $OEPNLKADMIN_PATH/cluster_config_info
        echo -e $cluster_config_info > $OEPNLKADMIN_PATH/cluster_config_info
    #else
        #echo "exist"
    fi
    config_template
    etc_dir=$INSTALL_PATH/hetu-server-$openlk_version/etc
    line_catalog=`cat $OEPNLKADMIN_PATH/.etc/coordinator/node.properties|grep catalog.config-dir`
    deploy_template_config $etc_dir
    if [[ -z $line_catalog ]]
    then
        catalog_dir=${etc_dir}/catalog
    else
        IFS='=' read -ra keyvalue <<< "${line_catalog}"
        catalog_dir=${keyvalue[1]}
    fi
    addcatalog ${catalog_dir}
}
function deploy_template_config(){
    etc_dir=$1
    if [[ $ISSINGLE == false ]]
    then
        . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $COORDINATOR_IP "ls $etc_dir/node.properties" &> /dev/null
        ret=$?
    else
        ret=1
    fi
    if [[ $ret == 0 ]] # has heen installed on coordinator,it is adding nodes
    then
        whoami=`whoami`
        if [[ $whoami == openlkadmin ]]
        then
            line=`ssh openlkadmin@$COORDINATOR_IP "cat $etc_dir/node.properties|grep node.environment"`
        else
            line=`sshpass -p $CLUSTER_PASS ssh $COORDINATOR_IP "cat $etc_dir/node.properties|grep node.environment"`
        fi
        IFS='=' read -ra keyvalue <<< "${line}"
        environment_name="${keyvalue[1]}"
    else
        environment_name="openlookeng$(date "+%Y%m%d%H%M%S")"
    fi
    if [[ -z $environment_name ]]
    then
        environment_name="openlookeng$(date "+%Y%m%d%H%M%S")"
    fi

    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    version=`awk -v num1=${openlk_version%.*} -v num2=1.2 'BEGIN{print(num1>num2)?"0":"1"}'`

    for ip in ${host_array[@]}
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            #rm -rf $etc_dir
            mkdir -p $etc_dir
            if [[ "$COORDINATOR_IP" == "$ip" ]]
            then
                deployed_file_cn=""
                all_config=`ls $OEPNLKADMIN_PATH/.etc/coordinator`
                for config_path in ${all_config}
                do
                    config_name=${config_path##*/}
                    if [[ $version == 1 ]] && [[ $config_name == 'hetu-metastore.properties' ]] #less than 1.2
                    then
                        continue
                    fi
                    cp -r $OEPNLKADMIN_PATH/.etc/coordinator/$config_name $etc_dir
                        deployed_file_cn="$deployed_file_cn,[$config_name]"

                done
                echo "[INFO] Deploy ${deployed_file_cn:1} on coordinator node successful."
            else
                deployed_file=""
                all_config=`ls $OEPNLKADMIN_PATH/.etc/worker`
                for config_path in ${all_config}
                do
                    config_name=${config_path##*/}
                    if [[ $version == 1 ]] && [[ $config_name == 'hetu-metastore.properties' ]] ##less than 1.2
                    then
                        continue
                    fi
                    cp -r $OEPNLKADMIN_PATH/.etc/worker/$config_name $etc_dir
                        deployed_file="$deployed_file,[$config_name]"
                done

            fi
            sed -i "1i node.id=$(cat /proc/sys/kernel/random/uuid)" $etc_dir/node.properties
            sed -i "s/\(^node.environment=\).*/\1${environment_name}/" $etc_dir/node.properties
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "mkdir -p $etc_dir"
            if [[ $COORDINATOR_IP == $ip ]]
            then
                #. $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OEPNLKADMIN_PATH/.etc/coordinator/* $etc_dir
                deployed_file_cn=""
                all_config=`ls $OEPNLKADMIN_PATH/.etc/coordinator`
                for config_path in ${all_config}
                do
                    config_name=${config_path##*/}
                    . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OEPNLKADMIN_PATH/.etc/coordinator/$config_name $etc_dir
                    deployed_file_cn="$deployed_file_cn,[$config_name]"
                done
                echo "[INFO] Deploy ${deployed_file:1} on coordinator node  successful."
            else
                deployed_file=""
                all_config=`ls $OEPNLKADMIN_PATH/.etc/worker`
                for config_path in ${all_config}
                do
                    config_name=${config_path##*/}
                    . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OEPNLKADMIN_PATH/.etc/worker/$config_name $etc_dir
                    deployed_file="$deployed_file,[$config_name]"
                done
            fi
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip  "sed -i '1i node.id=$(cat /proc/sys/kernel/random/uuid)' $etc_dir/node.properties;sed -i '/node.environment*/d' $etc_dir/node.properties;sed -i '1anode.environment=${environment_name}' $etc_dir/node.properties "
        fi
    done
    if [[ ! -z ${deployed_file} ]]
    then
        echo "[INFO] Deploy ${deployed_file:1} on worker node successful."
    fi
    rm -rf $OEPNLKADMIN_PATH/.etc
}

function config_template()
{
    if [[ ! -f $OEPNLKADMIN_PATH/cluster_config_info ]]
    then
        echo "[ERROR] Configuration file isn't exist."
        return 1
    fi
    cat $OEPNLKADMIN_PATH/cluster_config_info | while read line
    do
        #prop="$(cut -d '=' -f1 <<< $line)"
        #val="$(cut -d '=' -f2 <<< $line)"
        IFS='=' read -ra config <<< "$line"
        prop=${config[0]}
        val=${config[1]}
        gen_config coordinator $prop $val
        gen_config worker $prop $val
    done

}
function gen_config()
{
    role=$1
    prop=$2
    val=$3
    if [[ -d $OEPNLKADMIN_PATH/.etc/$role ]]
    then
        all_config=`ls $OEPNLKADMIN_PATH/.etc/$role`
        for config_path in ${all_config}
        do
            config_name=${config_path##*/}
            if [[ ! -z $val ]]
            then
                sed -i "s=<$prop>=$val=gI" $OEPNLKADMIN_PATH/.etc/$role/$config_name
            fi
        done
        if [[ -f $OEPNLKADMIN_PATH/.etc/$role/config.properties ]]
        then
            sed -i "s=<COORDINATOR_IP>=$COORDINATOR_IP=gI" $OEPNLKADMIN_PATH/.etc/$role/config.properties
        fi
    fi
}
function deploy_catalog()
{
    catalog_dir=$1
    all_config=`ls $OEPNLKADMIN_PATH/catalog/*.properties`
    IFS=',' read -ra host_array <<< "$PASSLESS_NODES"
    for ip in ${host_array[@]}
    do
        if [[ " ${local_ips_array[@]} " == *" ${ip} "* ]] || [[ "${ip}" == "localhost" ]]
        then
            deployed_catalog=""
            for config_path in ${all_config}
            do
                config_name=${config_path##*/}
                mkdir -p ${catalog_dir}
                cp $OEPNLKADMIN_PATH/catalog/$config_name $catalog_dir
                deployed_catalog="$deployed_catalog,[$config_name]"
            done
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "mkdir -p ${catalog_dir}"
            deployed_catalog=""
            for config_path in ${all_config}
            do
                config_name=${config_path##*/}
                . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OEPNLKADMIN_PATH/catalog/$config_name $catalog_dir
                deployed_catalog="$deployed_catalog,[$config_name]"
            done

        fi
    done
    echo "[INFO] Deploy catalogs ${deployed_catalog:1} success."
}
function addcatalog()
{
    catalog_dir="${1}"
    if [[ ! -d $catalog_dir ]]
    then
        mkdir $catalog_dir
    fi
    if [[ ! -d $OEPNLKADMIN_PATH/catalog ]]
    then
        mkdir -p $OEPNLKADMIN_PATH/catalog
    fi
    addcatalog_tpch
    addcatalog_tpcds
    addcatalog_mem

    deploy_catalog ${catalog_dir}

}
function addcatalog_mem()
{
    if [[ ! -f $OEPNLKADMIN_PATH/catalog/memory.properties ]]
    then
        touch $OEPNLKADMIN_PATH/catalog/memory.properties
        echo -e "connector.name=memory" > $OEPNLKADMIN_PATH/catalog/memory.properties
    fi
    currentversion=${openlk_version%.*}
    version=`awk -v num1=$currentversion -v num2=1.2 'BEGIN{print(num1>num2)?"0":"1"}'`
    grep -n "memory.spill-path" /home/openlkadmin/.openlkadmin/catalog/memory.properties
    if [[ version == 0 && $? != 0 ]] ##bigger than 1.2
    then
        echo -e "memory.spill-path=/opt/openlookeng" >> $OEPNLKADMIN_PATH/catalog/memory.properties
    fi
}
function addcatalog_tpch()
{
    if [[ ! -f $OEPNLKADMIN_PATH/catalog/tpch.properties ]]
    then
        touch $OEPNLKADMIN_PATH/catalog/tpch.properties
        echo -e "connector.name=tpch\ntpch.splits-per-node=4" > $OEPNLKADMIN_PATH/catalog/tpch.properties
    fi
}
function addcatalog_tpcds()
{
    if [[ ! -f $OEPNLKADMIN_PATH/catalog/tpcds.properties ]]
    then
        touch $OEPNLKADMIN_PATH/catalog/tpcds.properties
        echo -e "connector.name=tpcds\ntpcds.splits-per-node=4" > $OEPNLKADMIN_PATH/catalog/tpcds.properties
    fi
}
function main()
{
    if [[ $ISINSTALL == true ]]
    then
        if [[ $UPGRADE == true ]]
        then
            etc_dir=$INSTALL_PATH/hetu-server-$openlk_version/etc
            catalog_conf=`cat ${OEPNLKADMIN_PATH}/.etc/coordinator/node.properties|grep "catalog.config-dir"`
            IFS='=' read -ra catalog_array <<< "${catalog_conf}"
            deploy_template_config $etc_dir
            catalog_dir=${catalog_array[1]}
            if [[ -z $catalog_dir ]]
            then
                catalog_dir=$etc_dir/catalog
            fi
            deploy_catalog $catalog_dir
        else
            init_config_template
            if [[ $? != 0 ]]
            then
                return 1
            fi
        fi
    else
        if [[ ! -d $OEPNLKADMIN_PATH/.etc_template ]]
        then
            echo "[ERROR] Configuration template lost."
            return 1
        fi
        if [[ ! -f $OEPNLKADMIN_PATH/cluster_config_info ]]
        then
            echo "[ERROR] Configuration file $OEPNLKADMIN_PATH/cluster_config_info doesn't exist"
            return 1
        fi
        if [[ -d $OEPNLKADMIN_PATH/.etc ]]
        then
            rm -rf $OEPNLKADMIN_PATH/.etc
        fi
        cp -r $OEPNLKADMIN_PATH/.etc_template $OEPNLKADMIN_PATH/.etc
        config_template
        if [[ $? != 0 ]]
        then
            return 1
        fi
        etc_dir=$INSTALL_PATH/hetu-server/etc
        deploy_template_config $etc_dir
    fi
}
main $@
