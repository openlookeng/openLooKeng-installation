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
function install_server()
{
    offline=$1
    if [[ ! -d $OEPNLKADMIN_PATH ]]
    then
        mkdir -p $OEPNLKADMIN_PATH
        chown -R openlkadmin:openlkadmin $OEPNLKADMIN_PATH
    fi
    if [[ -z $offline ]]
    then
        echo "curl -fsSL -o $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz.sha256sum $wget_url/$openlk_version/hetu-server-$openlk_version.tar.gz.sha256sum"
        curl -fsSL -o $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz.sha256sum $wget_url/$openlk_version/hetu-server-$openlk_version.tar.gz.sha256sum
        if [[ ! -f $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz ]]
        then
            echo "[INFO] openLooKeng server package not found. Downloading it now..."
            curl -fsSL -o $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz $wget_url/$openlk_version/hetu-server-$openlk_version.tar.gz
            #wget -P $OEPNLKADMIN_PATH $wget_url/hetu-server-$openlk_version.tar.gz
            if [[ $? != 0 ]]
            then
                echo "[ERROR] Failed to download openLooKeng server package."
                exit 1
            fi
        fi
        cd $OEPNLKADMIN_PATH &> /dev/null
        res=$(sha256sum -c hetu-server-$openlk_version.tar.gz.sha256sum|grep OK|wc -l)
        if [[ $res > 0 ]]
        then
            echo "[INFO] Integrity verification of openLooKeng install package succeeded."
            rm -rf hetu-server-$openlk_version.tar.gz.sha256sum
        else
            echo "[INFO] OpenLooKeng server package is not latest. Downloading it again now..."
            curl -fsSL -o $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz $wget_url/$openlk_version/hetu-server-$openlk_version.tar.gz
            if [[ $? != 0 ]]
            then
                echo "[ERROR] Failed to download openLooKeng server package."
                exit 1
            fi
            res=$(sha256sum -c hetu-server-$openlk_version.tar.gz.sha256sum|grep OK|wc -l)
            if [[ $res > 0 ]]
            then
                echo "[INFO] Integrity verification of openLooKeng install package succeeded."
                rm -rf hetu-server-$openlk_version.tar.gz.sha256sum
            else
                echo "[ERROR] Integrity verification of openLooKeng install package failed. Exit now ..."
                exit 1
            fi
        fi
    else
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/hetu-server-$openlk_version.tar.gz ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/hetu-server-$openlk_version.tar.gz doesn't exist."
            return 1
        fi
        cp $OPENLOOKENG_DEPENDENCIES_PATH/hetu-server-$openlk_version.tar.gz $OEPNLKADMIN_PATH

    fi
    cd - &> /dev/null
    count=`ls $INSTALL_PATH|grep hetu-server|grep -v grep|wc -l`
    #if [[ $count > 0 ]]
    #then
        #rm -rf $INSTALL_PATH/hetu-server*
    #fi
    echo "[INFO] Deploying openLooKeng server ... "
    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    for ip in ${host_array[@]}
    do
        echo "[INFO] Deploying package to $ip..."
        if [[ *" ${ip} "* == " ${local_ips_array[@]} " ]] || [[ "$ip" == "localhost" ]]
        then

            tar -zxvf $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz -C $INSTALL_PATH &> /dev/null # local deploying
            cd $INSTALL_PATH &> /dev/null
            ln -s $INSTALL_PATH/hetu-server-$openlk_version hetu-server
            cd - &> /dev/null
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OEPNLKADMIN_PATH/hetu-server-$openlk_version.tar.gz /opt
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "mkdir -p $INSTALL_PATH;tar -zxvf /opt/hetu-server-$openlk_version.tar.gz -C $INSTALL_PATH;rm -rf /opt/hetu-server-$openlk_version.tar.gz;cd $INSTALL_PATH;ln -s $INSTALL_PATH/hetu-server-$openlk_version hetu-server;cd -" &> /dev/null
        fi
    done

    echo "[INFO] Deploy openLooKeng service Successful."
}
install_server $@
