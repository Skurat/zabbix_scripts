#!/usr/bin/env bash
version="6.4"
zabbix_server_url="http://localhost:8080/zabbix/api_jsonrpc.php"
user="Admin"
admin_pass="3wxcZB0C3xnj"

auth_via_admin(){
        data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$user/" | sed "s/\$api_user_pass/$admin_pass/")
        ADMIN_AUTHORIZATION_TOKEN_RESULT=$(curl -s --request POST \
        --url "$zabbix_server_url" \
        --header 'Content-Type: application/json-rpc' \
        --data $data_auth)
        #  | grep -o -P '"result":"(\w+)' | tail -n1 | cut -d':' -f2 | grep -o -P '\w+'
        if [[ "$(echo $ADMIN_AUTHORIZATION_TOKEN_RESULT | grep 'error')" ]]; then
            return 0
        else
            ADMIN_AUTHORIZATION_TOKEN="$(echo $ADMIN_AUTHORIZATION_TOKEN_RESULT | grep -o -P '"result":"(\w+)' | tail -n1 | cut -d':' -f2 | grep -o -P '\w+')"
            echo "${ADMIN_AUTHORIZATION_TOKEN}"
        fi
}

check_if_group_exist(){
    GROUP_ID="$1"
    ADMIN_AUTHORIZATION_TOKEN="$(auth_via_admin)"
    data_check_group=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_group_exist.json  | sed "s/\$groupid/$GROUP_ID/" | sed 's/groupids/groupid/')
    GROUP_EXIST=$(curl -s --request POST \
        --url "$zabbix_server_url" \
        --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
        --header 'Content-Type: application/json-rpc' \
        --data "$data_check_group")
    if [[ "$(echo $GROUP_EXIST | grep 'name')" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Check if hosts group same as in hosts.txt
check_same_config_as_in_hosts(){
    ADMIN_AUTHORIZATION_TOKEN="$(auth_via_admin)"
    if [[ "$ADMIN_AUTHORIZATION_TOKEN" ]]; then
            HOST_IP="$1"
            GROUP_ID="$2"
            data_check_host=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist_v2.json  | sed "s/\$agent_ip/$HOST_IP/")
            CHECK_HOST_GROUP=$(curl -s --request POST \
                --url "$zabbix_server_url" \
                --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
                --header 'Content-Type: application/json-rpc' \
                --data "$data_check_host")
            echo "IP - $HOST_IP"
            if [[ "$(echo $CHECK_HOST_GROUP | grep 'hostid')" ]]; then
                HOST_ID="$(echo "$CHECK_HOST_GROUP" | grep -o -P '\"hostid\":\"\d+\"' | grep -o -P "\d+" | tail -n1)"
                if [[ ! "$(echo CHECK_HOST_GROUP | grep '{"groupid":"'"$GROUP_ID"'"}')" ]]; then
                    GROUP_EXIST="$(check_if_group_exist "$GROUP_ID")"
                    echo "GROUP_EXIST = $GROUP_EXIST"
                    if [[ "${GROUP_EXIST}" == 'true' ]]; then
                        data_update_host=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_update_host.json  | sed "s/\$hostid/$HOST_ID/" | sed "s/\$groupid/$GROUP_ID/" | sed "s/\"${GROUP_ID}\"/{\"groupid\":\"${GROUP_ID}\"}/")
                        echo "IF = $HOST_IP - $data_update_host"
                        curl -s --request POST \
                            --url "$zabbix_server_url" \
                            --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
                            --header 'Content-Type: application/json-rpc' \
                            --data $data_update_host
                    else
                        GROUP_ID="26"
                        data_update_host=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_update_host.json  | sed "s/\$hostid/$HOST_ID/" | sed "s/\$groupid/$GROUP_ID/" | sed "s/\"${GROUP_ID}\"/{\"groupid\":\"${GROUP_ID}\"}/")
                        echo "ELSE = $HOST_IP - $data_update_host"
                        # Request for add host
                        curl -s --request POST \
                        --url "$zabbix_server_url" \
                        --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
                        --header 'Content-Type: application/json-rpc' \
                        --data $data_update_host
                    fi
                fi
            fi
            echo "-------------------"
    fi
}



recheck_if_hosts_group_same_as_in_hosts_txt(){
    while read line; do
        HOST_IP="$(echo $line | grep -o -P '^(\d{1,3}\.){3}\d{1,3}')"
        GROUP_ID="$(echo $line | awk '{print $2}' | grep -o -P '(\d+)')"
        if [[ "$(echo $HOST_IP | grep -o -P '^(\d{1,3}\.){3}\d{1,3}')" ]]; then
           check_same_config_as_in_hosts "${HOST_IP}" "${GROUP_ID}"
        fi
    done < "/root/hosts.txt"
}

recheck_if_hosts_group_same_as_in_hosts_txt