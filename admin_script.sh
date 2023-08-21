#!/usr/bin/env bash
version="6.4"
zabbix_server_url="http://65.108.196.236:8080/zabbix/api_jsonrpc.php"
user=""
admin_pass=""


check_if_host_exist(){
    AUTHORIZATION_TOKEN="$1"
    HOST_IP="$2"
    get_host_data=$(wget -qO- "https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist_v2.json" | sed "s/\$agent_ip/$HOST_IP/" )
    # get_host_data='{"jsonrpc":"2.0","method":"host.get","params":{"output":["hostid","host","ip","groupids"],"filter":{"ip":"'"$HOST_IP"'"},"selectGroups":["groupid"],"selectInterfaces":["ip"]},"id":1}'
    exist=$(curl --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$get_host_data")
    hosts_id=( $(echo "$exist" | grep -o -E "hostid\"\:\"\d+" | grep -o -E "\d+") )
    groups_id=( $(echo "$exist" | grep -o -E "groupid\"\:\"\d+" | grep -o -E "\d+") )
    hosts_ip=( $(echo "$exist" | grep -o -E "ip\"\:\"(\d+\.?\d{1,3}){4}") )
    # len=${#hosts_id[@]}
    for (( i=0; i < ${#hosts_id[@]}; i++ )); do
        if [[ ! $( echo "${groups_id[$i]}" | grep '25') ]]; then
                # echo "HOST ID ${hosts_id[$i]}"
                # echo "GROUP ID ${groups_id[$i]}"
                # echo "${hosts_ip[$i]}"  | grep -o -E "(\d+\.?\d{1,3}){4}"
                # echo "==============="
                delete_host_from_not_temp_group "$AUTHORIZATION_TOKEN" "${hosts_id[$i]}"
        fi
        # echo ${hosts_id[$i]}
    done
}

get_hosts_id_from_temp_group(){
    api_user="api_user"
    api_user_pass="y0#rZjb.RnQgsLw"
    data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$api_user/" | sed "s/\$api_user_pass/$api_user_pass/")
    AUTHORIZATION_TOKEN=$(curl --request POST \
    --url "$zabbix_server_url" \
    --header 'Content-Type: application/json-rpc' \
    --data $data_auth)
    echo "API_USER TOKEN $AUTHORIZATION_TOKEN"
    if [[ $(echo $AUTHORIZATION_TOKEN | grep 'result') ]]; then
        AUTHORIZATION_TOKEN=$(echo $AUTHORIZATION_TOKEN | cut -d',' -f2 | cut -d':' -f2 | sed -r 's/"//g')
    else
        echo "! ! ! Login or password is incorrect"
        exit 0
    fi
    get_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_check_if_host_exist.json  | sed "s/\"ip\"\:\[\"\$agent_ip\"\]\,//")
    exist=$(curl --request POST \
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
    AUTHORIZATION_TOKEN=$(curl --request POST \
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
    ip=$(curl --request POST \
    --url "$zabbix_server_url" \
    --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
    --header 'Content-Type: application/json-rpc' \
    --data "$get_host_data")
    host_ip=$(echo "$ip" | grep -o -E '(\d+\.?\d{1,3}){4}' )
    if [[ $(echo $ip | grep "ip") ]]; then
        echo "$host_ip"
    else
        echo ""
    fi
}

delete_host_from_not_temp_group(){
    AUTHORIZATION_TOKEN="$1"
    HOST_ID="$2"
    echo "------ HOST ID $HOST_ID"
    delete_host_data=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_delete_host.json | sed "s/\$host_id/$HOST_ID/" )
    # curl --request POST \
    # --url "$zabbix_server_url" \
    # --header "Authorization: Bearer ${AUTHORIZATION_TOKEN}" \
    # --header 'Content-Type: application/json-rpc' \
    # --data "$delete_host_data"

}

main(){
    data_auth=$(wget -qO- https://raw.githubusercontent.com/Skurat/zabbix_scripts/main/zabbix_authorization.json  | sed "s/\$api_user/$user/" | sed "s/\$api_user_pass/$admin_pass/")
    AUTHORIZATION_TOKEN=$(curl --request POST \
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
    for host in "${hosts_id[@]}"; do
        # Get hosts ip via hosts_id
        host_ip=$( get_host_ip_from_temp_group "$host" )
        echo "HOST IP = $host_ip"
        check_if_host_exist "$AUTHORIZATION_TOKEN" "$host_ip"
        # delete_host_from_not_temp_group "$AUTHORIZATION_TOKEN"
    done
    # hosts_ip=( $(get_hosts_ip_from_temp_group ${hosts_id[@]}) )
    # get_hosts_id_from_temp_group "$AUTHORIZATION_TOKEN"
    # check_if_host_exist "$AUTHORIZATION_TOKEN"

}

main