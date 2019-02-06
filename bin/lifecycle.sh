#!/usr/bin/env bash

#
# set the variables (see below)
#
# run:
#   bash ./lifecycle.sh
#
# The following script is an example in bash/cURL that performs most of the same
# actions as the Postman scripts do. Use this as an alternative way to interact
# with the API if you prefer to use cURL over Postman to experiment. Running this
# script will start a journey and change a step in the lifecycle.
#
# In order to use this script, you must have cURL and JQ installed and be running
# from a bash environment.
#
# Edit the variables in this script and create a lifecycle in the Chassi UI before running it.
#


##
##
## Begin variables
##
##


#
# App Space Details
#
#    Go to https://app.chassi.com/iam-and-admin/#/application-spaces (click on (i) icon)
#

# Set your tenant sub-domain name (only the prefix before '.')
#   Example:  mno-987-abc-321 (not mno-987-abc-321.api.chassi.com)
export SUB_DOMAIN="YOUR_SUB_DOMAIN_GOES_HERE"

# Set your Admin App Space identifier (UUID of App Space that holds shared definitions like Lifecycle Process Map, Tags, Preferences)
export ADMIN_APP_SPACE_ID="YOUR_ADMIN_APP_SPACE_ID_GOES_HERE"

# Set your App Space identifier (UUID of App Space that holds operational data like Entity Lifecycles, Customers, Contacts, etc.)
#   Note: in your Experiment space, Admin and Operational are the same
export APP_SPACE_ID="YOUR_APP_SPACE_ID_GOES_HERE"



#
# Authentication
#
#    USER_NAME / USER_PASS with grant_type=password
#           -or
#    CLIENT_ID / CLIENT_SECRET with grant_type=client_credentials
#
#    but dont mix
#

export CLIENT_ID_OR_USER_NAME='YOUR_USERNAME_OR_CLIENT_ID_GOES_HERE'
export CLIENT_SECRET_OR_USER_PASS='YOUR_USER_PASSWORD_OR_CLIENT_SECRET_GOES_HERE'
export GRANT_TYPE='password'  # literal string 'password' or 'client_credential'


#
# Lifecycle Details - go to https://app.chassi.com/api-customer-lifecycle#/inventory
#

# used to find lifecycle id for new entity lifecycle
export LIFECYCLE_NAME="YOUR_LIFECYCLE_NAME_GOES_HERE"


# used to change step on an entity lifecycle
export STEP_NAME="YOUR_STEP_NAME_GOES_HERE"





# External Customer ID - from YOUR system or crm or otherwise how you reference your customer
#export EXTERNAL_CUSTOMER_ID="customer-$(date "+%s")"   # using epoch timestamp for unique customer ids just for example
export EXTERNAL_CUSTOMER_ID="YOUR_CUSTOMER_IDENTIFIER_GOES_HERE"
echo "external customer id: $EXTERNAL_CUSTOMER_ID"




# OPTIONAL / Bonus Points: Attach to a Customer
#
export CHASSI_CUSTOMER_ID="YOUR_CHASSI_CUSTOMER_IDENTIFIER_GOES_HERE"
echo "chassi customer id: $CHASSI_CUSTOMER_ID"


##
##
## End variables
##
##



##
##
## Check Installed Utils
##
##

echo "=== Checking Utility Installs ==="


# make sure curl is installed
export IS_CURL_INSTALLED=$(which curl)
if [ -z "$IS_CURL_INSTALLED" ]; then
    echo "You must have curl installed. see https://curl.haxx.se"
fi

# make sure jq is installed to parse curl json responses:
#
#        https://stedolan.github.io/jq/download
#
export IS_JQ_INSTALLED=$(which jq)
if [ -z "$IS_JQ_INSTALLED" ]; then
    echo "You must have jq installed. see https://stedolan.github.io/jq/download"
fi



# bail if any not installed
if [ -z "$IS_CURL_INSTALLED" ] || [ -z "$IS_JQ_INSTALLED" ]; then
    echo "bailing out"
    exit -1
fi





# constructing full domain (dont change) using tenant sub-domain above
#   Example:  mno-987-abc-321.api.chassi.com
export FULL_DOMAIN="$SUB_DOMAIN.api.chassi.com"
echo "tenant domain name: $FULL_DOMAIN"




###
###
### Lifecycle Details
###
###



# <b>-- BE SURE TO GRAB A FRESH TOKEN --</b>
export ACCESS_TOKEN=$(curl -s -k -X "POST" "https://auth.chassi.com/auth/realms/chassi/protocol/openid-connect/token" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -H 'Accept: application/json' \
     --data-urlencode "username=$CLIENT_ID_OR_USER_NAME" \
     --data-urlencode "password=$CLIENT_SECRET_OR_USER_PASS" \
     --data-urlencode "grant_type=$GRANT_TYPE" \
     --data-urlencode "client_id=chassi-api" \
     | jq -r ".access_token")


# Lifecycle Inventory - Get the Inventory (list) of Lifecycles
## You will need this for the lifecycleId and lifecycle versionNo

echo "=== Lifecyle Details ==="
echo "trying GET https://$FULL_DOMAIN/$APP_SPACE_ID/lifecycle/1/lifecycles"

export LIFECYCLE_JSON=$(curl -s -k -X "GET" "https://$FULL_DOMAIN/$ADMIN_APP_SPACE_ID/lifecycle/1/lifecycles" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json")

echo "lifecycles (id and name):"
echo "$LIFECYCLE_JSON" | jq -r '.[] | .lifecycleId + " " + .lifecycleName'


# from the Inventory list, select the right lifecycle:

export LIFECYCLE_ID=$(echo $LIFECYCLE_JSON | jq -r ".[] | select(.lifecycleName==\"$LIFECYCLE_NAME\") | .lifecycleId")  # to get it, go to https://chassi.com/...
echo "selecting lifecycle id: $LIFECYCLE_ID"

export LIFECYCLE_VERSION_NO=$(echo $LIFECYCLE_JSON | jq -r ".[] | select(.lifecycleName==\"$LIFECYCLE_NAME\") | .lifecycleVersions | first | .versionNo")   # assume last one is published
echo "lifecycle version no: $LIFECYCLE_VERSION_NO"


#echo $LIFECYCLE_JSON | jq -r ".[] | select(.lifecycleName==\"$LIFECYCLE_NAME\") | .lifecycleVersions | .[] | select(.published==true) "

export LIFECYCLE_VERSION_JSON=$(echo $LIFECYCLE_JSON | jq -r ".[] | select(.lifecycleName==\"$LIFECYCLE_NAME\") | .lifecycleVersions | .[] | select(.published==true)")
#echo $LIFECYCLE_VERSION_JSON

export LIFECYCLE_VERSION_STEPS_JSON=$(echo $LIFECYCLE_VERSION_JSON | jq -r ".steps")
#echo $LIFECYCLE_VERSION_STEPS_JSON

# list the lifecycle version steps (steps in the process map of the published version)
echo "lifecycle version step list:"
echo $LIFECYCLE_VERSION_STEPS_JSON | jq -r ".[] | .stepId + \" \" + .stepName"

export LIFECYCLE_VERSION_SINGLE_STEP_JSON=$(echo $LIFECYCLE_VERSION_STEPS_JSON | jq -r ".[] | select(.stepName==\"$STEP_NAME\")")      # to get it, go to https://chassi.com/...
#echo "single step json: $LIFECYCLE_VERSION_SINGLE_STEP_JSON"

export LIFECYCLE_VERSION_STEP_ID=$(echo $LIFECYCLE_VERSION_SINGLE_STEP_JSON | jq -r ".stepId")


echo "selecting lifecycle step id: $LIFECYCLE_VERSION_STEP_ID"



###
###
### Start tracking a new Entity Lifecycle (New Entity Lifecyle)
###
###

#
# Token Refresh - grabbing a fresh token
#
export ACCESS_TOKEN=$(curl -s -k -X "POST" "https://auth.chassi.com/auth/realms/chassi/protocol/openid-connect/token" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -H 'Accept: application/json' \
     --data-urlencode "username=$CLIENT_ID_OR_USER_NAME" \
     --data-urlencode "password=$CLIENT_SECRET_OR_USER_PASS" \
     --data-urlencode "grant_type=$GRANT_TYPE" \
     --data-urlencode "client_id=chassi-api" \
     | jq -r ".access_token")


# New Entity Lifecycle (start tracking)
#
# Defaults to 'Start Step' so no need to 'Change Step' to it
#
## Example Payload:
##
## {
##   "lifecycleId": "123e4567-e89b-12d3-a456-426655440001",
##   "versionNo": 1,
##   "externalCustomerId": "123e4567-e89b-12d3-a456-426655440001"
## }
#
#

echo "=== New Entity Lifecyle ==="

export ENTITY_LIFECYCLE_JSON=$(curl -s -k -X "POST" "https://$FULL_DOMAIN/$APP_SPACE_ID/lifecycle/1/entitylifecycles" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "{ \"customerId\": \"$CHASSI_CUSTOMER_ID\", \"externalCustomerId\": \"$EXTERNAL_CUSTOMER_ID\", \"lifecycleId\": \"$LIFECYCLE_ID\", \"versionNo\": $LIFECYCLE_VERSION_NO}"
)
echo "entity lifecycle json: $ENTITY_LIFECYCLE_JSON"

export ENTITY_LIFECYCLE_ID=$(echo $ENTITY_LIFECYCLE_JSON | jq -r '.entityLifecycleId')

echo "entity lifecycle id: $ENTITY_LIFECYCLE_ID"






###
###
### Entity Lifecycle Change Step (repeat the following for each step change)
###
###   - First, get the Entity Lifecycle by its External Customer ID
###   - Then, change its step
###




#
# Token Refresh - grabbing a fresh token
#
export ACCESS_TOKEN=$(curl -s -k -X "POST" "https://auth.chassi.com/auth/realms/chassi/protocol/openid-connect/token" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -H 'Accept: application/json' \
     --data-urlencode "username=$CLIENT_ID_OR_USER_NAME" \
     --data-urlencode "password=$CLIENT_SECRET_OR_USER_PASS" \
     --data-urlencode "grant_type=$GRANT_TYPE" \
     --data-urlencode "client_id=chassi-api" \
     | jq -r ".access_token")



#
# Get Entity Lifecycle by External Customer Id
#

echo "=== Get Entity Lifecycle by External Customer Id ==="
export ENTITY_LIFECYCLE_JSON=$(curl -s -k -X "GET" "https://$FULL_DOMAIN/$APP_SPACE_ID/lifecycle/1/entitylifecycles?externalCustomerIds%5B%5D=$EXTERNAL_CUSTOMER_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json'
)

echo "get entity lifecyle by external customer id json: $ENTITY_LIFECYCLE_JSON"

export ENTITY_LIFECYCLE_ID=$(echo $ENTITY_LIFECYCLE_JSON | jq -r '.[0].entityLifecycleId')

echo "entity lifecycle id: $ENTITY_LIFECYCLE_ID"














###
###
### Show list of Entity Lifecycles
###
###   - First, get the Entity Lifecycle by its External Customer ID
###   - Then, change its step
###


#
# Token Refresh - grabbing a fresh token
#
export ACCESS_TOKEN=$(curl -s -k -X "POST" "https://auth.chassi.com/auth/realms/chassi/protocol/openid-connect/token" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -H 'Accept: application/json' \
     --data-urlencode "username=$CLIENT_ID_OR_USER_NAME" \
     --data-urlencode "password=$CLIENT_SECRET_OR_USER_PASS" \
     --data-urlencode "grant_type=$GRANT_TYPE" \
     --data-urlencode "client_id=chassi-api" \
     | jq -r ".access_token")



#
# Get All Entity Lifecycles (CAUTION: could get big)
#

# echo "=== Get Entity Lifecycles ==="
# export ENTITY_LIFECYCLE_LIST_JSON=$(curl -s -k -X "GET" "https://$FULL_DOMAIN/$APP_SPACE_ID/lifecycle/1/entitylifecycles" \
#     -H "Authorization: Bearer $ACCESS_TOKEN" \
#     -H 'Content-Type: application/json' \
#     -H 'Accept: application/json'
# )
# echo $ENTITY_LIFECYCLE_LIST_JSON | jq '.'




##
##
## OPTIONAL - Attach to Chassi Customer
##
##


#
# Token Refresh - grabbing a fresh token
#
export ACCESS_TOKEN=$(curl -s -k -X "POST" "https://auth.chassi.com/auth/realms/chassi/protocol/openid-connect/token" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -H 'Accept: application/json' \
     --data-urlencode "username=$CLIENT_ID_OR_USER_NAME" \
     --data-urlencode "password=$CLIENT_SECRET_OR_USER_PASS" \
     --data-urlencode "grant_type=$GRANT_TYPE" \
     --data-urlencode "client_id=chassi-api" \
     | jq -r ".access_token")


export CUSTOMER_JOURNEY_JSON=$(curl -s -k -X "POST" "https://$FULL_DOMAIN/$APP_SPACE_ID/customer/1/customers/{customerId}/journeys" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "{ \"customerId\": \"$CHASSI_CUSTOMER_ID\", \"entityLifecycleId\": \"$ENTITY_LIFECYCLE_ID\" }"
)
echo "customer journey json: $CUSTOMER_JOURNEY_JSON"









##
## Entity Lifecycle Step Change
##

# entityLifecycleId from /<app space>/lifecycle/1/entitylifecycles?
#
#    Example Payload
#       {
#         "entityLifecycleId": "123e4567-e89b-12d3-a456-426655440001",
#         "stepId": "123e4567-e89b-12d3-a456-426655440001",
#         "stepName": "example"
#       }
#
#     **Note:
#       stepName is ignored on this endpoint so is used as comment.
#       use lifecycle version to actually change a step name
#

 echo "=== Entity Lifecycle Step Change ==="
 curl -s -k -X "PUT" "https://$FULL_DOMAIN/$APP_SPACE_ID/lifecycle/1/entitylifecycles/$ENTITY_LIFECYCLE_ID/change-step" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json' \
     -d $"{ \"entityLifecycleId\": \"$ENTITY_LIFECYCLE_ID\", \"stepId\": \"$LIFECYCLE_VERSION_STEP_ID\" }"
 echo ""

















