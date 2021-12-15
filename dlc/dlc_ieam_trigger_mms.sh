#!/bin/bash

# The type and name of the MMS file we are using
OBJECT_ID="$HZN_DEVICE_ID.$SERVICE_NAME-deployment"
OBJECT_TYPE="logsources.json"
OBJECT_RECEIVED=0

# ${HZN_ESS_AUTH} is mounted to this container by the Horizon agent and is a json file with the credentials for authenticating to ESS.
# ESS (Edge Sync Service) is a proxy to MMS that runs in the Horizon agent.
USER=$(cat ${HZN_ESS_AUTH} | jq -r ".id")
PW=$(cat ${HZN_ESS_AUTH} | jq -r ".token")

# Some curl parameters for using the ESS REST API
AUTH="-u ${USER}:${PW}"
# ${HZN_ESS_CERT} is mounted to this container by the Horizon agent and the cert clients use to verify the identity of ESS.
CERT="--cacert ${HZN_ESS_CERT}"
SOCKET="--unix-socket ${HZN_ESS_API_ADDRESS}"
BASEURL="https://localhost/api/v1/objects"

DEBUG=1

echo "Listen for logsources.json changes"
LOGSOURCES="/dlcInstance/logsources.json"

RC=-1
i=0

while (($RC != 0)); do

	# See if there is a new version of the config.json file
    	if [[ $DEBUG == 1 ]]; then echo "DEBUG: Checking for MMS updates" ; fi
    	HTTP_CODE=$(curl -sSLw "%{http_code}" -o objects.meta ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE)  # will only get changes that we haven't acknowledged (see below)
    	if [[ "$HTTP_CODE" != '200' && "$HTTP_CODE" != '404' ]]; then 
		echo "Error: HTTP code $HTTP_CODE from: curl -sSLw %{http_code} -o objects.meta ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE"; fi

    	if [[ $DEBUG == 1 ]]; then echo "DEBUG: MMS metadata=$(cat objects.meta)"; fi

        # objects.meta is a json array of all MMS files of OBJECT_TYPE that have been updated. Search for the ID we are interested in
    	OBJ_ID=$(jq -r ".[] | select(.objectID == \"$OBJECT_ID\") | .objectID" objects.meta)  # if not found, jq returns 0 exit code, but blank value

	if [[ "$HTTP_CODE" == '200' && "$OBJ_ID" == $OBJECT_ID ]]; then
        
		if [[ $DEBUG == 1 ]]; then echo "DEBUG: Received new metadata for $OBJ_ID"; fi

        	# Handle the case in which MMS is telling us the config file was deleted
        	DELETED=$(jq -r ".[] | select(.objectID == \"$OBJECT_ID\") | .deleted" objects.meta)  # if not found, jq returns 0 exit code, but blank value
        	if [[ "$DELETED" == "true" ]]; then
            
			if [[ $DEBUG == 1 ]]; then echo "DEBUG: MMS file $OBJECT_ID was deleted, reverting to original $OBJECT_ID"; fi

            		# Acknowledge that we saw that it was deleted, so it won't keep telling us
            		HTTP_CODE=$(curl -sSLw "%{http_code}" -X PUT ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE/$OBJECT_ID/deleted)
            		if [[ "$HTTP_CODE" != '200' && "$HTTP_CODE" != '204' ]]; then 
				echo "Error: HTTP code $HTTP_CODE from: curl -sSLw %{http_code} -X PUT ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE/$OBJECT_ID/deleted"; fi

            		# Revert back to the original config file from the docker image
		   	mv $LOGSOURCES $LOGSOURCES.bak	

        	else

                        if [[ $DEBUG == 1 ]]; then echo "DEBUG: Received new/updated $OBJECT_ID from MMS"; fi

            		# Read the new file from MMS
            		HTTP_CODE=$(curl -sSLw "%{http_code}" -o $OBJECT_TYPE ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE/$OBJECT_ID/data)
            		if [[ "$HTTP_CODE" != '200' ]]; then 
				echo "Error: HTTP code $HTTP_CODE from: curl -sSLw %{http_code} -o $OBJECT_TYPE ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE/$OBJECT_ID/data"; fi
            		#ls -l $OBJECT_ID

            		# Acknowledge that we got the new file, so it won't keep telling us
            		HTTP_CODE=$(curl -sSLw "%{http_code}" -X PUT ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE/$OBJECT_ID/received)
            		if [[ "$HTTP_CODE" != '200' && "$HTTP_CODE" != '204' ]]; then 
				echo "Error: HTTP code $HTTP_CODE from: curl -sSLw %{http_code} -X PUT ${AUTH} ${CERT} $SOCKET $BASEURL/$OBJECT_TYPE/$OBJECT_ID/received"; fi
        	fi

		#delete objects.meta
                rm objects.meta

		#work on received file
		if [[ $DEBUG == 1 ]]; then echo "DEBUG: RECEIVED INSTANCE.JSON"; fi

		cp $OBJECT_TYPE $LOGSOURCES
		#do something

		cp /opt/ibm/si/services/dlc/conf/logSources.json /opt/ibm/si/services/dlc/conf/logSources.json.last
		cp $LOGSOURCES /opt/ibm/si/services/dlc/conf/logSources.json

		RC=0
		if [[ $DEBUG == 1 ]]; then echo "DEBUG: RECEIVED LOG SOURCES"; fi

	else	

		#BREATHE
 		if [[ $DEBUG == 1 ]]; then echo "DEBUG: WAIT LOG SOURCES"; fi	
		sleep 5

		((i=i+1))
		if [[ $i > 6 ]]; then RC=0; fi
	fi

done

if [[ $DEBUG == 1 ]]; then echo "DEBUG: RELOAD DLC.SERVICE"; fi
