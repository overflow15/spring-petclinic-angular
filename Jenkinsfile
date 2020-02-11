podTemplate(label: 'jnlp-petclinic-front', serviceAccount: 'jenkins', slaveConnectTimeout: '600', containers: [
    containerTemplate(
            name: 'npm',
            image: 'node:13.7.0-stretch',
            ttyEnabled: true,
            resourceLimitCpu: '1000m',
            resourceLimitMemory: '1500Mi',
            resourceRequestCpu: '250m',
            resourceRequestMemory: '256Mi',
            command: 'cat',
            envVars: [
                secretEnvVar(key: 'SONAR_URL', secretName: 'sonar-petclinic', secretKey: 'url'),
                secretEnvVar(key: 'SONAR_USER', secretName: 'sonar-petclinic', secretKey: 'username'),
                secretEnvVar(key: 'SONAR_PASS', secretName: 'sonar-petclinic', secretKey: 'password'),
                secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password')
            ]
    ),
    containerTemplate(
            name: 'python',
            image: 'python:3.7.6-alpine3.10',
            ttyEnabled: true,
            command: 'cat',
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            privileged: true,
            envVars: [
                secretEnvVar(key: 'SONAR_URL', secretName: 'sonar-petclinic', secretKey: 'url'),
                secretEnvVar(key: 'SONAR_USER', secretName: 'sonar-petclinic', secretKey: 'username'),
                secretEnvVar(key: 'SONAR_PASS', secretName: 'sonar-petclinic', secretKey: 'password'),
            ]
    ),
    containerTemplate(
            name: 'docker',
            image: 'lordgaav/dind-options',
            ttyEnabled: true,
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            privileged: true,
            envVars: [
                secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password'),
                envVar(key: 'DOCKER_OPTS', value: '--insecure-registry=docker.eks.minlab.com')
            ]
    ),
    containerTemplate(
            name: 'helm',
            image: 'dtzar/helm-kubectl:2.16.0',
            ttyEnabled: true,
            command: 'cat',
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            envVars: [
                secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password')
            ]
    )
    ]
)
{
    node('jnlp-petclinic-front') {
        stage('Checkout') {
            checkout scm
            container('npm') {
              stage('Unit tests') {
                  sh '''#!/bin/bash
                  export NG_CLI_ANALYTICS=ci
                  export CHROME_BIN=chromium
                  apt-get update
                  apt-get install -y chromium
                  npm uninstall -g angular-cli @angular/cli
                  npm cache clean --force
                  npm install -g @angular/cli@latest
                  npm install
                  npm i -D handlebars@4.5.0
                  npm test
                  '''
              }
              stage('Publishing to Nexus') {
                  sh '''#!/bin/bash
                  ng build
                  npm publish --registry http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus-sonatype-nexus-npm:8081/repository/npm
                  '''
              }
              stage('Sonar') {
                  sh '''#!/bin/bash
                  #sed -i "s/application_name/$(grep "name" package.json | awk -F\" '{print $4}')/g" sonar-project.properties
                  #sed -i "s/application_version/$(grep "version" package.json | awk -F\" '{print $4}')/g" sonar-project.properties
                  npm install -D sonarqube-scanner
                  npm run sonar
                  taskID=$(curl $(tail -1 .scannerwork/report-task.txt | cut -d '=' -f2-3) |  cut -d ',' -f7 | cut -d ':' -f2 | cut -d '"' -f2)
                  while [ "$taskID" = "IN_PROGRESS" ] || [ "$taskID" = "PENDING" ]; do sleep 5; taskID=$(curl $(tail -1 .scannerwork/report-task.txt | cut -d '=' -f2-3) |  cut -d ',' -f7 | cut -d ':' -f2 | cut -d '"' -f2); done
                  status=$(curl -u ${SONAR_USER}:${SONAR_PASS} ${SONAR_URL}/api/qualitygates/project_status?analysisId=${taskID} | cut -d ',' -f1 |  cut -d '"' -f6)
                  if [ "$status" != "OK" ]; then exit 1; fi
                  '''
              }
            }
        }
        stage('Send Sonar data to InfluxDB') {
            container('python') {
              stage('Send Sonar data to InfluxDB') {
                  sh '''
                  python3 -m pip install influxdb
                  apk --update add git less openssh
                  cd /tmp && git clone https://github.com/overflow15/sonarqube-influxdb.git
                  cd sonarqube-influxdb
                  echo "sonarUser="$SONAR_USER >> python/application.properties
                  echo "sonarCredentials="$SONAR_PASS >> python/application.properties
                  python python/qamera.py python/application.properties spring-petclinic-angular
                  '''
              }
            }
        }
        stage('DinD') {
            container('docker') {
              stage('installing DinD dependencies') {
                  sh '''
                  appName=$(grep "name" package.json | awk -F'"' '{print $4}')
                  appVersion=$(grep "version" package.json | awk -F'"' '{print $4}')
                  apk --update add curl
                  curl -X GET http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/npm/$appName/-/$appName-$appVersion.tgz --output $appName-$appVersion.tgz
                  sed -i "s/application_package/$appName-$appVersion.tgz/g"
                  docker build -t ${appName}:latest .
                  '''
              }
              stage('Docker tag and push') {
                  sh '''
                  appName=$(grep "name" package.json | awk -F'"' '{print $4}')
                  appVersion=$(grep "version" package.json | awk -F'"' '{print $4}')
                  tag_nexus=$(date +%s) && docker tag $appName:latest docker.eks.minlab.com/repository/docker-registry/$appName:${tag_nexus}
                  docker login http://docker.eks.minlab.com -uadmin -p$(echo -ne $NEXUS_ADMIN_PASS)
                  docker push docker.eks.minlab.com/repository/docker-registry/$appName:${tag_nexus}
                  '''
              }
            }
        }
        stage('Deploy') {
            container('helm') {
              stage('Helm upgrade') {
                  sh '''#!/bin/bash
                  appName=$(grep "name" package.json | awk -F'"' '{print $4}')
                  image_tag=$(curl -u admin:$(echo -ne $NEXUS_ADMIN_PASS) -X GET http://nexus.eks.minlab.com/service/rest/v1/search/ | grep path | grep docker | awk -F'"' '{print $4}' | grep ${appName} | awk -F/ '{print $6}' | sort -nr | head -1)
                  helm upgrade --install --force ${appName} --set-string deployment.image.tag=$(echo $image_tag) --set-string deployment.image.repository="docker.eks.minlab.com/repository/docker-registry/$appName" -f Helm_Chart/values.yaml Helm_Chart/. --tiller-namespace cicd-tools --namespace cicd-tools
                  '''
              }
            }
        }
    }
}
