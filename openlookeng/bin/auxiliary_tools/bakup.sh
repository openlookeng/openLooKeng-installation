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
function main()
{
    whoami=`whoami`
    server_dir=hetu-server
    #bakup etc
    if [[ -d $OEPNLKADMIN_PATH/.etc ]]
    then
        rm -rf $OEPNLKADMIN_PATH/.etc/*
    else
        mkdir -p $OEPNLKADMIN_PATH/.etc
    fi
    mkdir -p $OEPNLKADMIN_PATH/.etc/coordinator
    mkdir -p $OEPNLKADMIN_PATH/.etc/worker
    chown -R openlkadmin:openlkadmin $OEPNLKADMIN_PATH/.etc
    IFS=',' read -ra host_array <<< "${WORKER_NODES}"
    if [[ $whoami == openlkadmin ]]
    then
        scp -r $COORDINATOR_IP:$INSTALL_PATH/$server_dir/etc/* $OEPNLKADMIN_PATH/.etc/coordinator &> /dev/null
        scp -r ${host_array[0]}:$INSTALL_PATH/$server_dir/etc/* $OEPNLKADMIN_PATH/.etc/worker &> /dev/null
    else
        su openlkadmin <<EOF
        scp -r $COORDINATOR_IP:$INSTALL_PATH/$server_dir/etc/* $OEPNLKADMIN_PATH/.etc/coordinator &> /dev/null
        scp -r ${host_array[0]}:$INSTALL_PATH/$server_dir/etc/* $OEPNLKADMIN_PATH/.etc/worker &> /dev/null
EOF
    fi
    sed -i '/node.id/d' $OEPNLKADMIN_PATH/.etc/coordinator/node.properties
    sed -i '/node.id/d' $OEPNLKADMIN_PATH/.etc/worker/node.properties
    #backup catalog
    if [[ -d $OEPNLKADMIN_PATH/catalog ]]
    then
        rm -rf $OEPNLKADMIN_PATH/catalog/*
    else
        mkdir -p $OEPNLKADMIN_PATH/catalog
    fi
    catalog=`su openlkadmin -c "ssh -o StrictHostKeyChecking=no $COORDINATOR_IP \"cat $INSTALL_PATH/$server_dir/etc/node.properties|grep \"catalog.config-dir\"|grep -v grep\""`
    IFS='=' read -ra catalog_array <<< "${catalog}"
    catalog_dir=${catalog_array[1]}
    if [[ -z $catalog_dir ]]
    then
        catalog_dir=$INSTALL_PATH/$server_dir/etc/catalog
    fi
    
    if [[ $whoami == openlkadmin ]]
    then
        scp -r $COORDINATOR_IP:$catalog_dir/*  $OEPNLKADMIN_PATH/catalog &> /dev/null
    else
        su openlkadmin <<EOF
        scp -r $COORDINATOR_IP:$catalog_dir/*  $OEPNLKADMIN_PATH/catalog &> /dev/null
EOF
    fi
}
main$@