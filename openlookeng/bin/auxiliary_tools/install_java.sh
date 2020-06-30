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
##############################################################
## @Company: HUAWEI Tech. Co., Ltd.
## @Filename appctl.sh
## @Usage
## @Description openLooKeng auto deployment
## @Options
## @History
## @Version
## @Created 2019.03.11
##############################################################

declare FILE_NAME="install_java.sh"

#################################################### log print #################################################
res=`arch|grep x86|wc -l`
if [[  $res > 0 ]]
then
    architecture=x86
else
    architecture=arrch64
fi
function install_jdk()
{
    offline=$1
    if [[ $architecture == x86 ]]
    then
        arch_name=x64
    else
        arch_name=$architecture
    fi
    if [[ $offline == 0 ]]
    then
        if [ ! -f "/opt/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz" ]
        then
            echo "[INFO] Starting download jdk8u222b10 package..."
            #wget -P /opt $1 &> /dev/null
            curl -fsSL -o /opt/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz $resource_url/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz
        fi 
        tar -zxvf /opt/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz -C /opt/ >>/dev/null 2>&1
    else
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz doesn't exit."
            return 1
        fi
        cp $OPENLOOKENG_DEPENDENCIES_PATH/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz /opt
    fi    
    
    if [ $? -ne 0 ]
    then
        echo "[INFO] JDK installation failed"
        exit -1
    else
        sed -i '#*/opt/jdk#d' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        sed -i '/root\/bin/d' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        sed -i '/JAVA_HOME/d' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        sed -i '/CLASSPATH/d' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        
        sed -i '$aJAVA_HOME=/opt/jdk8u222-b10' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        sed -i '$aPATH=/opt/jdk8u222-b10/bin:$PATH:$HOME/bin' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        sed -i '$aCLASSPATH=.:/opt/jdk8u222-b10jdk8u222-b10/lib/dt.jar:/opt/jdk8u222-b10/lib/tools.jar' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        sed -i '$aexport PATH JAVA_HOME CLASSPATH' /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`

        source /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
        echo "JDK just installed success, java home is: ${JAVA_HOME}"
    fi
    rm -f /opt/OpenJDK8U-jdk_${arch_name}_linux_hotspot_8u222b10.tar.gz
    return 0
}

function main()
{    
    offline=$1
    resource_url=$2
    source /home/openlkadmin/`ls -a /home/openlkadmin/|grep profile`
    java -version &> /dev/null
    ret=$?
    java_version=`java -version 2>&1 |awk 'NR==1{ gsub(/"/,""); print $3 }'`
    if [[ $ret != 0 ]]
    then
        echo "[INFO] JDK is not installed, need install auto, java_version is:${java_version}, sub_version is: ${sub_version}"
        install_jdk $offline||{ ret=$?; return ${ret}; }
        exit $?
    fi
    version8=`echo ${java_version}|grep '_'`
    if [[ ! -z ${version8} ]]
    then
        main_version=${java_version:2:1}
        sub_version=`echo ${java_version} |awk -F'_' '{print $2}'` 
    else
        main_version=${java_version:0:1}
        sub_version=`echo ${java_version} |awk -F'.' '{print $3}'`
    fi
    if [[ ${main_version} == 8 ]] && [[ ${sub_version} -le 151 ]]
    then
        echo "[INFO] the current java_version:${java_version} need update to satisfy openLooKeng's need"
        install_jdk $offline|| { ret=$?; return ${ret}; }
    elif [[ ${main_version} < 8 ]]
    then
        echo "[INFO] the current java_version:${java_version} need update to satisfy openLooKeng's need"
        install_jdk $offline|| { ret=$?; return ${ret}; }
    else
        echo "[INFO] JDK is already installed! version is: ${java_version}"
    fi
    return 0
}

main $@
