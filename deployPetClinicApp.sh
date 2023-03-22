#!/bin/bash
set -e

# ==== Customize the below for your environment====
resource_group='monitor-lab04-rg'
region='eastus'
spring_apps_service='monitortfapp'
mysql_server_name='tfmonitor-mysql'
mysql_server_admin_name='azuser'
mysql_server_admin_password='P@55w.rd'
log_analytics='monitortflog'

#########################################################
# When error happened following function will be executed
#########################################################

function error_handler() {
az group delete --no-wait --yes --name $resource_group
echo "ERROR occured :line no = $2" >&2
exit 1
}

trap 'error_handler $? ${LINENO}' ERR
#########################################################
# Resource Creation
#########################################################

#Add Required extensions
az extension add --name spring

#set variables
DEVBOX_IP_ADDRESS=$(curl ifconfig.me)

#Create directory for github code
project_directory=$HOME
cd ${project_directory}
mkdir -p source-code
cd source-code
rm -rdf spring-petclinic-microservices

#Clone GitHub Repo
printf "\n"
printf "Cloning the sample project: https://github.com/azure-samples/spring-petclinic-microservices"
printf "\n"

git clone https://github.com/azure-samples/spring-petclinic-microservices
cd spring-petclinic-microservices
mvn clean package -DskipTests -Denv=cloud

# ==== Service and App Instances ====
api_gateway='api-gateway'
admin_server='admin-server'
customers_service='customers-service'
vets_service='vets-service'
visits_service='visits-service'

# ==== JARS ====
api_gateway_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-api-gateway/target/spring-petclinic-api-gateway-3.0.1.jar"
admin_server_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-admin-server/target/spring-petclinic-admin-server-3.0.1.jar"
customers_service_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-customers-service/target/spring-petclinic-customers-service-3.0.1.jar"
vets_service_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-vets-service/target/spring-petclinic-vets-service-3.0.1.jar"
visits_service_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-visits-service/target/spring-petclinic-visits-service-3.0.1.jar"

# ==== MYSQL INFO ====
mysql_server_full_name="${mysql_server_name}.mysql.database.azure.com"
mysql_server_admin_login_name="${mysql_server_admin_name}@${mysql_server_full_name}"
mysql_database_name='petclinic'

cd "${project_directory}/source-code/spring-petclinic-microservices"

printf "\n"
printf "Creating the Resource Group: ${resource_group} Region: ${region}"
printf "\n"

az group create --name ${resource_group} --location ${region}

printf "\n"
printf "Creating the MySQL Server: ${mysql_server_name}"
printf "\n"

az mysql server create \
    --resource-group ${resource_group} \
    --name ${mysql_server_name} \
    --location ${region} \
    --sku-name GP_Gen5_2 \
    --storage-size 5120 \
    --admin-user ${mysql_server_admin_name} \
    --admin-password ${mysql_server_admin_password} \
    --ssl-enforcement Disabled

az mysql server firewall-rule create \
    --resource-group ${resource_group} \
    --name ${mysql_server_name}-database-allow-local-ip \
    --server ${mysql_server_name} \
    --start-ip-address ${DEVBOX_IP_ADDRESS} \
    --end-ip-address ${DEVBOX_IP_ADDRESS}

az mysql server firewall-rule create \
    --resource-group ${resource_group} \
    --name allAzureIPs \
    --server ${mysql_server_name} \
    --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

printf "\n"
printf "Creating the Spring Apps: ${spring_apps_service}"
printf "\n"

az spring create \
    --resource-group ${resource_group} \
    --name ${spring_apps_service} \
    --location ${region} \
    --sku standard \
    --disable-app-insights false \
    --enable-java-agent true

az configure --defaults group=${resource_group} location=${region}

az spring config-server set --config-file application.yml --name ${spring_apps_service}

printf "\n"
printf "Creating the microservice apps"
printf "\n"

#az spring app create --name ${api_gateway} --instance-count 1 --assign-endpoint true \
#   --memory 2Gi --jvm-options='-Xms2048m -Xmx2048m'

az spring app create  -n ${api_gateway}  -s ${spring_apps_service}  -g ${resource_group} --assign-endpoint true --cpu 2 --memory 3Gi --instance-count 3 --runtime-version Java_17

#az spring app create --name ${admin_server} --instance-count 1 --assign-endpoint true \
#    --memory 2Gi --jvm-options='-Xms2048m -Xmx2048m'

az spring app create  -n ${admin_server}  -s ${spring_apps_service}  -g ${resource_group} --assign-endpoint true --cpu 2 --memory 2Gi --instance-count 3 --runtime-version Java_17

#az spring app create --name ${customers_service} \
#    --instance-count 1 --memory 2Gi --jvm-options='-Xms2048m -Xmx2048m'

az spring app create  -n ${customers_service}  -s ${spring_apps_service}  -g ${resource_group} --assign-endpoint true --cpu 2 --memory 2Gi --instance-count 3 --runtime-version Java_17

#az spring app create --name ${vets_service} \
#    --instance-count 1 --memory 2Gi --jvm-options='-Xms2048m -Xmx2048m'

az spring app create  -n ${vets_service}  -s ${spring_apps_service}  -g ${resource_group} --assign-endpoint true --cpu 2 --memory 2Gi --instance-count 3 --runtime-version Java_17

#az spring app create --name ${visits_service} \
#    --instance-count 1 --memory 2Gi --jvm-options='-Xms2048m -Xmx2048m'

az spring app create  -n ${visits_service}  -s ${spring_apps_service}  -g ${resource_group} --assign-endpoint true --cpu 2 --memory 2Gi --instance-count 3 --runtime-version Java_17


# increase connection timeout
az mysql server configuration set --name wait_timeout \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value 2147483

az mysql server configuration set --name slow_query_log \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value ON

az mysql server configuration set --name audit_log_enabled \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value ON

az mysql server configuration set --name audit_log_events \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value "ADMIN,CONNECTION,DCL,DDL,DML,DML_NONSELECT,DML_SELECT,GENERAL,TABLE_ACCESS"

az mysql server configuration set --name log_queries_not_using_indexes \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value ON

az mysql server configuration set --name long_query_time \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value 0

#mysql Configuration 
mysql -h"${mysql_server_full_name}" -u"${mysql_server_admin_login_name}" \
     -p"${mysql_server_admin_password}" \
     -e  "CREATE DATABASE petclinic;CREATE USER 'root' IDENTIFIED BY 'petclinic';GRANT ALL PRIVILEGES ON petclinic.* TO 'root';"

mysql -h"${mysql_server_full_name}" -u"${mysql_server_admin_login_name}" \
     -p"${mysql_server_admin_password}" \
     -e  "CALL mysql.az_load_timezone();"

az mysql server configuration set --name time_zone \
  --resource-group ${resource_group} \
  --server ${mysql_server_name} --value "US/Central"

az mysql server configuration set --name query_store_capture_mode \
  --resource-group ${resource_group} \
  --server ${mysql_server_name} --value ALL

az mysql server configuration set --name query_store_capture_interval \
  --resource-group ${resource_group} \
  --server ${mysql_server_name} --value 5

printf "\n"
printf "Deploying the apps to Spring Apps"
printf "\n"

#az spring app deploy --name ${api_gateway} \
#    --artifact-path ${api_gateway_jar} \
#    --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql'

az spring app deploy -n ${api_gateway} -s ${spring_apps_service} -g ${resource_group} --artifact-path ${api_gateway_jar} --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --env foo=bar

#--env foo=bar --disable-validation

#az spring app deploy --name ${admin_server} \
#    --artifact-path ${admin_server_jar} \
#    --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql'

az spring app deploy -n ${admin_server} -s ${spring_apps_service} -g ${resource_group} --artifact-path ${admin_server_jar}  --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --env foo=bar

#az spring app deploy --name ${customers_service} \
#--artifact-path ${customers_service_jar} \
#--jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' \
#--env mysql_server_full_name=${mysql_server_full_name} \
#      mysql_database_name=${mysql_database_name} \
#      mysql_server_admin_login_name=${mysql_server_admin_login_name} \
#      mysql_server_admin_password=${mysql_server_admin_password}

az spring app deploy -n ${customers_service} -s ${spring_apps_service} -g ${resource_group} --artifact-path ${customers_service_jar}  --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --env mysql_server_full_name=${mysql_server_full_name} mysql_database_name=${mysql_database_name} mysql_server_admin_login_name=${mysql_server_admin_login_name} mysql_server_admin_password=${mysql_server_admin_password}


#az spring app deploy --name ${vets_service} \
#--artifact-path ${vets_service_jar} \
#--jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' \
#--env mysql_server_full_name=${mysql_server_full_name} \
#      mysql_database_name=${mysql_database_name} \
#      mysql_server_admin_login_name=${mysql_server_admin_login_name} \
#      mysql_server_admin_password=${mysql_server_admin_password}

az spring app deploy -n ${vets_service} -s ${spring_apps_service} -g ${resource_group} --artifact-path ${vets_service_jar}  --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --env mysql_server_full_name=${mysql_server_full_name} mysql_database_name=${mysql_database_name} mysql_server_admin_login_name=${mysql_server_admin_login_name} mysql_server_admin_password=${mysql_server_admin_password}


#az spring app deploy --name ${visits_service} \
#--artifact-path ${visits_service_jar} \
#--jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' \
#--env mysql_server_full_name=${mysql_server_full_name} \
#      mysql_database_name=${mysql_database_name} \
#      mysql_server_admin_login_name=${mysql_server_admin_login_name} \
#      mysql_server_admin_password=${mysql_server_admin_password}

az spring app deploy -n ${visits_service} -s ${spring_apps_service} -g ${resource_group} --artifact-path ${visits_service_jar}  --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' --env mysql_server_full_name=${mysql_server_full_name} mysql_database_name=${mysql_database_name} mysql_server_admin_login_name=${mysql_server_admin_login_name} mysql_server_admin_password=${mysql_server_admin_password}

printf "Application Deployment completed successfully"

printf "\n"
printf "Creating the log anaytics workspace: ${log_analytics}"
printf "\n"

az monitor log-analytics workspace create \
    --workspace-name ${log_analytics} \
    --resource-group ${resource_group} \
    --location ${region}           
                            
