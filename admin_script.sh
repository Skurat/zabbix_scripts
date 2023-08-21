#!/usr/bin/env bash
version="6.4"
zabbix_server_url="http://65.108.196.236:8080/zabbix/api_jsonrpc.php"
user=""
admin_pass=""


check_if_host_exist(){
    AUTHORIZATION_TOKEN="$1"
    HOST_IP="$2"
    get_host_data=$(wget -qO- "https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist_v2.json" | sed "s/\$agent_ip/$HOST_IP/" )
    # Get list of existing hosts with same ip
    exist=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$get_host_data")
    ## Test output START
    hosts_id=( $(echo "$exist" | grep -o -E "hostid\"\:\"\d+" | grep -o -E "\d+") )
    groups_id=( $(echo "$exist" | grep -o -E "groupid\"\:\"\d+" | grep -o -E "\d+") )
    hosts_ip=( $(echo "$exist" | grep -o -E "ip\"\:\"(\d+\.?\d{1,3}){4}") )
    ## Test output
    # len=${#hosts_id[@]}
    # echo $exist
    # echo "LEN OF GROUP IDS $len"
    # echo "GROUP IDS ${groups_id[@]}"
    # echo ""
    ## END
    for (( i=0; i < ${#hosts_id[@]}; i++ )); do
        if [[ ! $( echo "${groups_id[$i]}" | grep '25') ]]; then
                # Delete host with same ip in non temp group
                delete_host_from_not_temp_group "$AUTHORIZATION_TOKEN" "${hosts_id[$i]}"
                echo "Host with IP ${hosts_ip[$i]}, groupids ${groups_id[$i]} and hostid ${hosts_id[$i]} was removed" >> /tmp/removed_hosts.txt
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
    delete_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_delete_host.json | sed "s/\$host_id/$HOST_ID/" )
    curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$delete_host_data"
}

get_hosts_id_from_temp_group(){
    api_user="api_user"
    api_user_pass="y0#rZjb.RnQgsLw"
    data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$api_user/" | sed "s/\$api_user_pass/$api_user_pass/")
    AUTHORIZATION_TOKEN=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header 'Content-Type: application/json-rpc' \
    --data $data_auth)
    if [[ $(echo $AUTHORIZATION_TOKEN | grep 'result') ]]; then
        AUTHORIZATION_TOKEN=$(echo $AUTHORIZATION_TOKEN | cut -d',' -f2 | cut -d':' -f2 | sed -r 's/"//g')
    else
        echo "! ! ! Login or password is incorrect"
        exit 0
    fi
    get_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist.json  | sed "s/\"ip\"\:\[\"\$agent_ip\"\]\,//")
    exist=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
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
get_host_ip_from_temp_group(){
    api_user="api_user"
    api_user_pass="y0#rZjb.RnQgsLw"
    host_id="$1"
    data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$api_user/" | sed "s/\$api_user_pass/$api_user_pass/")
    AUTHORIZATION_TOKEN=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header 'Content-Type: application/json-rpc' \
    --data $data_auth)
    if [[ $(echo $AUTHORIZATION_TOKEN | grep 'result') ]]; then
        AUTHORIZATION_TOKEN=$(echo $AUTHORIZATION_TOKEN | cut -d',' -f2 | cut -d':' -f2 | sed -r 's/"//g')
    else
        echo "! ! ! Login or password is incorrect"
        exit 0
    fi
    get_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_admin_get_hosts_ip.json  | sed "s/\$host_id/$host_id/")
    ip=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
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
    AUTHORIZATION_TOKEN=$(curl -s --request POST \
    --url "$zabbix_server_url" \
    --header 'Content-Type: application/json-rpc' \
    --data $data_auth)
    # Check if auth creds valid
    if [[ $(echo $AUTHORIZATION_TOKEN | grep 'result') ]]; then
        AUTHORIZATION_TOKEN=$(echo $AUTHORIZATION_TOKEN | cut -d',' -f2 | cut -d':' -f2 | sed -r 's/"//g')
    else
        echo "! ! ! Login or password is incorrect"
        exit 0
    fi
    # Get hosts_id from temporarely group
    hosts_id=( $(get_hosts_id_from_temp_group) )
    echo "Got hosts id from temp group = ${hosts_id[@]}"

    for host in "${hosts_id[@]}"; do

        # Get hosts ip via hosts_id
        host_ip=$( get_host_ip_from_temp_group "$host" )

        # Check if same ip exist in non temp groups
        check_if_host_exist "$AUTHORIZATION_TOKEN" "$host_ip"
    done
}

main