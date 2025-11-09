#!/bin/bash

########################################################
# Script to register multiple UEs (Optimized Version 1)
#
# Changes:
# - Login only ONCE at the beginning.
# - Removed sleep 0.5 for maximum speed.
# - Passed imsi/plmn_id directly to action function
#   to avoid redundant jq/sed parsing.
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
    }
}'
# Removed FlowRules, QosFlows, ChargingDatas for brevity in template
# Add them back if you need them for your test

FREE5GC_CONSOLE_BASE_URL='http://127.0.0.1:5000'

# Import the login function
free5gc_console_login() {
    local token=$(curl -s -X POST $FREE5GC_CONSOLE_BASE_URL/api/login -H "Content-Type: application/json" -d "$LOGIN_DATA" | jq -r '.access_token')
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo "Failed to get token!" >&2
        return 1
    fi

    echo "$token"
    return 0
}

# Modified subscriber action function to accept TOKEN, IMSI, PLMN_ID
free5gc_console_subscriber_action() {
    local action=$1
    local json_data=$2
    local token=$3
    local imsi=$4
    local plmn_id=$5

    case $action in
        "post")
            if curl -s --fail -X POST $FREE5GC_CONSOLE_BASE_URL/api/subscriber/imsi-$imsi/$plmn_id -H "Content-Type: application/json" -H "Token: $token" -d "$json_data"; then
                return 0
            else
                return 1
            fi
        ;;
        "delete")
            if curl -s --fail -X DELETE $FREE5GC_CONSOLE_BASE_URL/api/subscriber/imsi-$imsi/$plmn_id -H "Content-Type: application/json" -H "Token: $token" -d "$json_data"; then
                return 0
            else
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
    # Use ' instead of " for the sed command to avoid issues with $SUBSCRIBER_TEMPLATE
    echo "$SUBSCRIBER_TEMPLATE" | sed "s/__IMSI__/$imsi/"
}

register_multiple_ues() {
    local action=$1
    local count=$2
    local success_count=0
    local fail_count=0
    
    echo "Attempting to login once..."
    local token=$(free5gc_console_login)
    if [ $? -ne 0 ]; then
        echo "Login failed. Exiting."
        return 1
    fi
    echo "Login successful. Re-using token for all requests."

    echo "Starting to ${action} ${count} UEs..."
    echo "Base IMSI: ${BASE_IMSI}"
    echo "----------------------------------------"
    
    for ((i=0; i<count; i++)); do
        local current_imsi=$((BASE_IMSI + i))
        
        echo -n "[$((i+1))/${count}] Processing UE with IMSI: ${current_imsi}... "
        
        # Generate subscriber data JSON string
        local json_data=$(generate_subscriber_data "$current_imsi")
        
        # Call the function with JSON data, TOKEN, IMSI, and PLMN_ID
        if free5gc_console_subscriber_action "$action" "$json_data" "$token" "$current_imsi" "$PLMN_ID"; then
            ((success_count++))
            echo "✓ Success"
        else
            ((fail_count++))
            echo "✗ Failed"
        fi
        
        # Removed "sleep 0.5"
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