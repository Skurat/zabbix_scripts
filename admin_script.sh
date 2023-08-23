#!/usr/bin/env bash
version="6.4"
zabbix_server_url="http://65.108.196.236:8080/zabbix/api_jsonrpc.php"
user=""
admin_pass=""

auth_via_api_user(){
        api_user="api_user"
        api_user_pass="y0#rZjb.RnQgsLw"
        data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$api_user/" | sed "s/\$api_user_pass/$api_user_pass/")
        API_USER_AUTHORIZATION_TOKEN_RESULT=$(curl -s --request POST \
        --url "$zabbix_server_url" \
        --header 'Content-Type: application/json-rpc' \
        --data $data_auth)
        #  | grep -o -E '"result":"(\w+)' | tail -n1 | cut -d':' -f2 | grep -o -E '\w+'
        if [[ "$(echo $API_USER_AUTHORIZATION_TOKEN_RESULT | grep 'error')" ]]; then
            return 0
        else
            API_USER_AUTHORIZATION_TOKEN="$(echo $API_USER_AUTHORIZATION_TOKEN_RESULT | grep -o -E '"result":"(\w+)' | tail -n1 | cut -d':' -f2 | grep -o -E '\w+')"
            echo "${API_USER_AUTHORIZATION_TOKEN}"
        fi
}

auth_via_admin(){
        data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$user/" | sed "s/\$api_user_pass/$admin_pass/")
        ADMIN_AUTHORIZATION_TOKEN_RESULT=$(curl -s --request POST \
        --url "$zabbix_server_url" \
        --header 'Content-Type: application/json-rpc' \
        --data $data_auth)
        #  | grep -o -E '"result":"(\w+)' | tail -n1 | cut -d':' -f2 | grep -o -E '\w+'
        if [[ "$(echo $ADMIN_AUTHORIZATION_TOKEN_RESULT | grep 'error')" ]]; then
            return 0
        else
            ADMIN_AUTHORIZATION_TOKEN="$(echo $ADMIN_AUTHORIZATION_TOKEN_RESULT | grep -o -E '"result":"(\w+)' | tail -n1 | cut -d':' -f2 | grep -o -E '\w+')"
            echo "${ADMIN_AUTHORIZATION_TOKEN}"
        fi
}

check_if_host_exist(){
    ADMIN_AUTHORIZATION_TOKEN="$(auth_via_admin)"
    if [[ "${ADMIN_AUTHORIZATION_TOKEN}" == "" ]]; then echo "! ! ! Invalid username or password"; exit 0; fi
    HOST_IP="$2"
    get_host_data=$(wget -qO- "https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist_v2.json" | sed "s/\$agent_ip/$HOST_IP/" )
    # Get list of existing hosts with same ip
    exist=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$get_host_data")
    # Declare var for logging in log file
    hosts_id=( $(echo "$exist" | grep -o -E "hostid\"\:\"\d+" | grep -o -E "\d+") )
    groups_id=( $(echo "$exist" | grep -o -E "groupid\"\:\"\d+" | grep -o -E "\d+") )
    hosts_ip=( $(echo "$exist" | grep -o -E "ip\"\:\"(\d+\.?\d{1,3}){4}") )
    ## Test output
    # len=${#hosts_id[@]}
    # echo "TOKEN  $ADMIN_AUTHORIZATION_TOKEN - $HOST_IP"
    # echo $exist
    # echo "LEN OF GROUP IDS $len"
    # echo "GROUP IDS ${groups_id[@]}"
    # echo ""
    ## END
    for (( i=0; i < ${#hosts_id[@]}; i++ )); do
        if [[ ! $( echo "${groups_id[$i]}" | grep '25') ]]; then
                # Delete host with same ip in non temp group
                delete_host_from_not_temp_group "$ADMIN_AUTHORIZATION_TOKEN" "${hosts_id[$i]}"
                echo "Host with IP ${hosts_ip[$i]}, groupids ${groups_id[$i]} and hostid ${hosts_id[$i]} was removed" >> removed_hosts.txt
        fi
    done
}

delete_host_from_not_temp_group(){
    AUTHORIZATION_TOKEN="$1"
    if [[ -z "$2" ]]; then
        echo "del func need host id"
        return 0
    fi
    HOST_ID="$2"
    echo "To delete host $HOST_ID"
    delete_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_delete_host.json | sed "s/\$host_id/$HOST_ID/" )
    curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$delete_host_data"
}
# By API_USER
get_hosts_id_from_temp_group(){
    api_user="api_user"
    api_user_pass="y0#rZjb.RnQgsLw"
    data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$api_user/" | sed "s/\$api_user_pass/$api_user_pass/")
    API_USER_AUTHORIZATION_TOKEN="$(auth_via_api_user)"
    if [[ "${API_USER_AUTHORIZATION_TOKEN}" == "" ]]; then echo "! ! ! Invalid username or password"; exit 0; fi
    get_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist.json  | sed "s/\"ip\"\:\[\"\$agent_ip\"\]\,//")
    exist=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${API_USER_AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$get_host_data")
    host_id=( $(echo "$exist" | grep -o -E 'hostid":"[0-9]{4,}"' | grep -E -o '[0-9]+') )
    if [[ $(echo $exist | grep "hostid") ]]; then
        echo "${host_id[@]}"
    else
        echo "Hosts does not exist"
        exit 0
    fi
}
# By API_USER
get_host_ip_from_temp_group(){
    API_USER_AUTHORIZATION_TOKEN="$(auth_via_api_user)"
    if [[ "${API_USER_AUTHORIZATION_TOKEN}" == "" ]]; then echo "! ! ! Invalid username or password"; exit 0; fi
    host_id="$1"
    get_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_admin_get_hosts_ip.json  | sed "s/\$host_id/$host_id/")
    ip=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${API_USER_AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$get_host_data")
    host_ip=$(echo "$ip" | grep -o -E '(\d+\.){3}\d{1,3}' | tail -n1 )
    if [[ $(echo $ip | grep "ip") ]]; then
        echo "$host_ip"
    else
        echo ""
    fi
}

main(){
    data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$user/" | sed "s/\$api_user_pass/$admin_pass/")
    ADMIN_AUTHORIZATION_TOKEN="$(auth_via_admin)"
    if [[ "${ADMIN_AUTHORIZATION_TOKEN}" == "" ]]; then echo "! ! ! Invalid username or password"; exit 0; fi

    # Get hosts_id from temporarely group
    hosts_id=( $(get_hosts_id_from_temp_group) )
    echo "Got hosts id from temp group = ${hosts_id[@]}"

    for host in "${hosts_id[@]}"; do

        # Get hosts ip via hosts_id
        host_ip=$( get_host_ip_from_temp_group "$host" )
        if [[ "$host_ip" ]]; then
            # Check if same ip exist in non temp groups
            check_if_host_exist "$ADMIN_AUTHORIZATION_TOKEN" "$host_ip"
        fi
        
    done
}
# By API_USER
get_host_id(){
    API_USER_AUTHORIZATION_TOKEN="$(auth_via_api_user)"
    if [[ "$API_USER_AUTHORIZATION_TOKEN" ]]; then
        get_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist.json  | sed "s/\$agent_ip/$HOST_IP/")
        # echo $get_host_data
        # return 0
        HOST_ID=$(curl -s --request POST \
        --url "$zabbix_server_url" \
        --header "Authorization: Bearer ${API_USER_AUTHORIZATION_TOKEN}" \
        --header 'Content-Type: application/json-rpc' \
        --data "$get_host_data" | grep -o -E '"hostid":"\d+' | tail -n1 | grep -o -E '\d+')
        if [[ -z "${HOST_ID}" ]]; then
            return 0
        else
            echo "${HOST_ID}"
        fi
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
move_agent_to_group(){
    HOST_IP="$1"
    GROUP_ID="$2"
    API_USER_AUTHORIZATION_TOKEN="$(auth_via_api_user)"
    ADMIN_AUTHORIZATION_TOKEN="$(auth_via_admin)"
    if [[ "$API_USER_AUTHORIZATION_TOKEN" ]]; then
        # echo "move_agent_to_group - API_USER_AUTHORIZATION_TOKEN ${API_USER_AUTHORIZATION_TOKEN}"
        HOST_ID="$(get_host_id "${HOST_IP}")"
        # echo $HOST_ID
        if [[ "${HOST_ID}" ]]; then
            # check_if_group_exist "$GROUP_ID"
            GROUP_EXIST="$(check_if_group_exist "$GROUP_ID")"
            if [[ "${GROUP_EXIST}" == 'true' ]]; then
                echo "--- Host $HOST_IP move to group $GROUP_ID"
                data_update_host=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_update_host.json  | sed "s/\$hostid/$HOST_ID/" | sed "s/\$groupid/$GROUP_ID/" | sed "s/\"${GROUP_ID}\"/{\"groupid\":\"${GROUP_ID}\"}/")
                echo $data_update_host
                # Request for add host
                curl --request POST \
                --url "$zabbix_server_url" \
                --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
                --header 'Content-Type: application/json-rpc' \
                --data $data_update_host
            else
                echo "Wrong group"
                GROUP_ID="26"
                echo "--- Host $HOST_IP move to group $GROUP_ID"
                data_update_host=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_update_host.json  | sed "s/\$hostid/$HOST_ID/" | sed "s/\$groupid/$GROUP_ID/" | sed "s/\"${GROUP_ID}\"/{\"groupid\":\"${GROUP_ID}\"}/")
                echo $data_update_host
                # Request for add host
                curl --request POST \
                --url "$zabbix_server_url" \
                --header "Authorization: Bearer ${ADMIN_AUTHORIZATION_TOKEN}" \
                --header 'Content-Type: application/json-rpc' \
                --data $data_update_host
            fi
            return 0
        fi
    else
        echo "! ! ! Invalid username or password ! ! !"
        exit 0
    fi
}
read_from_file(){
    while IFS= read line; do
        HOST_IP="$(echo $line | grep -o -E '^(\d{1,3}\.){3}\d{1,3}')"
        GROUP_ID="$(echo $line | awk '{print $2}' | grep -o -E '(\d+)')"
        move_agent_to_group "${HOST_IP}" "${GROUP_ID}"
    done < "hosts.txt"
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
            echo "$CHECK_HOST_GROUP"
            echo -------
            # if [[ "$(echo $CHECK_HOST_GROUP | grep '{"groupid":"'"$GROUP_ID"'"}' --color)" ]]; then
            #     echo "Ok $HOST_IP and $GROUP_ID"
            # else
            #     echo "Wrong $HOST_IP and $GROUP_ID"
            # fi
    fi
}
recheck_if_hosts_group_same_as_in_hosts_txt(){
    while IFS= read line; do
        HOST_IP="$(echo $line | grep -o -E '^(\d{1,3}\.){3}\d{1,3}')"
        GROUP_ID="$(echo $line | awk '{print $2}' | grep -o -E '(\d+)')"
        check_same_config_as_in_hosts "${HOST_IP}" "${GROUP_ID}"
    done < "hosts.txt"
}

main

read_from_file

# recheck_if_hosts_group_same_as_in_hosts_txt
