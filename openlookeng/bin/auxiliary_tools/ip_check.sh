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
function ip_check(){
    IP=$1
    if [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then   
        FIELD1=$(echo $IP|cut -d. -f1)   
        FIELD2=$(echo $IP|cut -d. -f2)   
        FIELD3=$(echo $IP|cut -d. -f3)   
        FIELD4=$(echo $IP|cut -d. -f4)   
        if [[ $FIELD1 -le 255 ]] && [[ $FIELD2 -le 255 ]] && [[ $FIELD3 -le 255 ]] && [[ $FIELD4 -le 255 ]]
        then   
            return 0
        fi
    fi
    return 1
}
ip_check $@