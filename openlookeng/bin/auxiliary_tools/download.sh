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
    if [[ $# != 1 ]]
    then
        echo "[ERROR] Package name is null."
        exit 1
    fi
    if [[ -z $wget_url ]]
    then
        echo "[ERROR] Didn't get download url."
        exit 1
    fi
    if [[ -f $package_name ]]
    then
        rm -f $package_name*
    fi
    echo "[INFO] Downloading package ${package_name} ..."
    URL="$wget_url/$package_name"
    if type wget &>/dev/null
    then
        echo "wget -O /opt/$package_name.sha256sum $URL.sha256sum"
        wget -O /opt/$package_name.sha256sum $URL.sha256sum
        echo "wget -O /opt/$package_name $URL"
        wget -O /opt/$package_name $URL
    elif type curl &>/dev/null
    then
        #wget -P . "$URL"
        curl -fsSL -o /opt/$package_name.sha256sum $wget_url/$package_name.sha256sum
        echo "curl -fsSL -o /opt/$package_name $wget_url/$package_name"
        curl -fsSL -o /opt/$package_name $wget_url/$package_name
    fi
    # download failed
    if test $? -ne 0
    then
        echo "[ERROR] Failed to download openLooKeng install package, please check your network connection is good."
        trap - EXIT QUIT TERM
        exit 1
    fi
}
main $@
retValue=$?
exit $retValue