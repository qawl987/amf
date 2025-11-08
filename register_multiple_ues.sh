#!/bin/bash

########################################################
# Script to register multiple UEs
#
# Usage:
#   ./register_multiple_ues.sh post [count]
#   ./register_multiple_ues.sh delete [count]
#
# Description:
#   This script registers or deletes multiple UEs using the 
#   free5gc_console_subscriber_action function.
#   
#   Default count is 5 UEs if not specified.
#   Base IMSI: 208930000000001, will increment for each UE
########################################################

# Hardcoded login data (from free5gc-console-login-data.json)
LOGIN_DATA='{"username": "admin", "password": "free5gc"}'

# Hardcoded subscriber data template (from free5gc-console-subscriber-data.json)
# Use __IMSI__ as placeholder for IMSI
SUBSCRIBER_TEMPLATE='{
    "plmnID": "20893",
    "ueId": "imsi-__IMSI__",
    "AuthenticationSubscription": {
        "authenticationManagementField": "8000",
        "authenticationMethod": "5G_AKA",
        "milenage": {
            "op": {
                "encryptionAlgorithm": 0,
                "encryptionKey": 0,
                "opValue": ""
            }
        },
        "opc": {
            "encryptionAlgorithm": 0,
            "encryptionKey": 0,
            "opcValue": "8e27b6af0e692e750f32667a3b14605d"
        },
        "permanentKey": {
            "encryptionAlgorithm": 0,
            "encryptionKey": 0,
            "permanentKeyValue": "8baf473f2f8fd09487cccbd7097c6862"
        },
        "sequenceNumber": "000000000023"
    },
    "AccessAndMobilitySubscriptionData": {
        "gpsis": [
            "msisdn-"
        ],
        "nssai": {
            "defaultSingleNssais": [
                {
                    "sst": 1,
                    "sd": "010203",
                    "isDefault": true
                }
            ]
        },
        "subscribedUeAmbr": {
            "downlink": "2 Gbps",
            "uplink": "1 Gbps"
        }
    },
    "SessionManagementSubscriptionData": [
        {
            "singleNssai": {
                "sst": 1,
                "sd": "010203"
            },
            "dnnConfigurations": {
                "internet": {
                    "sscModes": {
                        "defaultSscMode": "SSC_MODE_1",
                        "allowedSscModes": [
                            "SSC_MODE_2",
                            "SSC_MODE_3"
                        ]
                    },
                    "pduSessionTypes": {
                        "defaultSessionType": "IPV4",
                        "allowedSessionTypes": [
                            "IPV4"
                        ]
                    },
                    "sessionAmbr": {
                        "uplink": "200 Mbps",
                        "downlink": "100 Mbps"
                    },
                    "5gQosProfile": {
                        "5qi": 9,
                        "arp": {
                            "priorityLevel": 8
                        },
                        "priorityLevel": 8
                    }
                }
            }
        }
    ],
    "SmfSelectionSubscriptionData": {
        "subscribedSnssaiInfos": {
            "01010203": {
                "dnnInfos": [
                    {
                        "dnn": "internet"
                    }
                ]
            }
        }
    },
    "AmPolicyData": {
        "subscCats": [
            "free5gc"
        ]
    },
    "SmPolicyData": {
        "smPolicySnssaiData": {
            "01010203": {
                "snssai": {
                    "sst": 1,
                    "sd": "010203"
                },
                "smPolicyDnnData": {
                    "internet": {
                        "dnn": "internet"
                    }
                }
            }
        }
    },
    "FlowRules": [
        {
            "filter": "1.1.1.1/32",
            "precedence": 128,
            "snssai": "01010203",
            "dnn": "internet",
            "qosRef": 1
        }
    ],
    "QosFlows": [
        {
            "snssai": "01010203",
            "dnn": "internet",
            "qosRef": 1,
            "5qi": 8,
            "mbrUL": "208 Mbps",
            "mbrDL": "208 Mbps",
            "gbrUL": "108 Mbps",
            "gbrDL": "108 Mbps"
        }
    ],
    "ChargingDatas": [
        {
            "snssai": "01010203",
            "dnn": "",
            "filter": "",
            "chargingMethod": "Offline",
            "quota": "100000",
            "unitCost": "1"
        },
        {
            "snssai": "01010203",
            "dnn": "internet",
            "qosRef": 1,
            "filter": "1.1.1.1/32",
            "chargingMethod": "Offline",
            "quota": "100000",
            "unitCost": "1"
        }
    ]
}'

FREE5GC_CONSOLE_BASE_URL='http://127.0.0.1:5000'

# Import the login function
free5gc_console_login() {
    local token=$(curl -s -X POST $FREE5GC_CONSOLE_BASE_URL/api/login -H "Content-Type: application/json" -d "$LOGIN_DATA" | jq -r '.access_token')
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo "Failed to get token!"
        return 1
    fi

    echo "$token"
    return 0
}

# Modified subscriber action function to accept JSON data directly
free5gc_console_subscriber_action() {
    local action=$1
    local json_data=$2

    local token=$(free5gc_console_login)
    if [ -z "$token" ]; then
        echo "Failed to get token!"
        return 1
    fi

    local imsi=$(echo "$json_data" | jq -r '.ueId' | sed 's/imsi-//')
    local plmn_id=$(echo "$json_data" | jq -r '.plmnID')

    case $action in
        "post")
            if curl -s --fail -X POST $FREE5GC_CONSOLE_BASE_URL/api/subscriber/imsi-$imsi/$plmn_id -H "Content-Type: application/json" -H "Token: $token" -d "$json_data"; then
                echo "Subscriber created successfully!"
                return 0
            else
                echo "Failed to create subscriber!"
                return 1
            fi
        ;;
        "delete")
            if curl -s --fail -X DELETE $FREE5GC_CONSOLE_BASE_URL/api/subscriber/imsi-$imsi/$plmn_id -H "Content-Type: application/json" -H "Token: $token" -d "$json_data"; then
                echo "Subscriber deleted successfully!"
                return 0
            else
                echo "Failed to delete subscriber!"
                return 1
            fi
        ;;
    esac
}

# Default number of UEs to register
DEFAULT_UE_COUNT=5

# Base IMSI (will be incremented for each UE)
BASE_IMSI=208930000000001

# PLMN ID
PLMN_ID="20893"

Usage() {
    echo "Usage: $0 [post|delete] [count]"
    echo "  post   - Register UEs"
    echo "  delete - Delete UEs"
    echo "  count  - Number of UEs (default: 5)"
    echo ""
    echo "Examples:"
    echo "  $0 post 10       # Register 10 UEs"
    echo "  $0 delete 10     # Delete 10 UEs"
    echo "  $0 post          # Register 5 UEs (default)"
    exit 1
}

# Modified to return JSON string instead of writing to file
generate_subscriber_data() {
    local imsi=$1
    echo "$SUBSCRIBER_TEMPLATE" | sed "s/__IMSI__/$imsi/"
}

register_multiple_ues() {
    local action=$1
    local count=$2
    local success_count=0
    local fail_count=0
    
    echo "Starting to ${action} ${count} UEs..."
    echo "Base IMSI: ${BASE_IMSI}"
    echo "----------------------------------------"
    
    for ((i=0; i<count; i++)); do
        local current_imsi=$((BASE_IMSI + i))
        
        echo "[$((i+1))/${count}] Processing UE with IMSI: ${current_imsi}"
        
        # Generate subscriber data JSON string
        local json_data=$(generate_subscriber_data "$current_imsi")
        
        # Call the function with JSON data
        if free5gc_console_subscriber_action "$action" "$json_data"; then
            ((success_count++))
            echo "  ✓ Success"
        else
            ((fail_count++))
            echo "  ✗ Failed"
        fi
        
        # Small delay to avoid overwhelming the server
        sleep 0.5
    done
    
    echo "----------------------------------------"
    echo "Summary:"
    echo "  Total: ${count}"
    echo "  Success: ${success_count}"
    echo "  Failed: ${fail_count}"
    echo "----------------------------------------"
    
    if [ $fail_count -eq 0 ]; then
        echo "All UEs processed successfully!"
        return 0
    else
        echo "Some UEs failed to process."
        return 1
    fi
}

main() {
    if [ -z "$1" ]; then
        echo "Error: Action not specified!"
        Usage
    fi
    
    local action=$1
    local count=${2:-$DEFAULT_UE_COUNT}
    
    # Validate action
    if [[ "$action" != "post" && "$action" != "delete" ]]; then
        echo "Error: Invalid action '$action'. Must be 'post' or 'delete'."
        Usage
    fi
    
    # Validate count
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -le 0 ]; then
        echo "Error: Count must be a positive integer."
        Usage
    fi
    
    register_multiple_ues "$action" "$count"
}

main "$@"
