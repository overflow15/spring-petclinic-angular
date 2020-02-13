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
    ),
    containerTemplate(
            name: 'maven',
            image: 'maven:3.6.3-jdk-8',
            ttyEnabled: true,
            command: 'cat',
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            envVars: [
			    secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password')
			]
    ),
    containerTemplate(
            name: 'jdk',
            image: 'openjdk:8-jre-alpine',
            ttyEnabled: true,
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            envVars: []
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
                  appName=$(grep "name" package.json | cut -d '"' -f4)
                  cd /tmp && git clone https://github.com/overflow15/sonarqube-influxdb.git
                  cd sonarqube-influxdb
                  echo "sonarUser="$SONAR_USER >> python/application.properties
                  echo "sonarCredentials="$SONAR_PASS >> python/application.properties
                  python python/qamera.py python/application.properties ${appName}
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
                  sed -i "s/application_package/$appName-$appVersion.tgz/g" Dockerfile
                  docker build -t ${appName}:latest .
                  '''
              }
              stage('Docker tag and push') {
                  sh '''
                  appName=$(grep "name" package.json | awk -F'"' '{print $4}')
                  appVersion=$(grep "version" package.json | awk -F'"' '{print $4}')
                  docker tag $appName:latest docker.eks.minlab.com/repository/docker-registry/$appName:${appVersion}
                  docker login http://docker.eks.minlab.com -uadmin -p$(echo -ne $NEXUS_ADMIN_PASS)
                  docker push docker.eks.minlab.com/repository/docker-registry/$appName:${appVersion}
                  '''
              }
            }
        }
        stage('Deploy') {
            container('helm') {
              stage('Helm upgrade') {
                  sh '''#!/bin/bash
                  appName=$(grep "name" package.json | awk -F'"' '{print $4}')
                  appVersion=$(grep "version" package.json | awk -F'"' '{print $4}')
                  helm upgrade --install --force ${appName} --set-string deployment.image.tag=$(echo $appVersion) --set-string deployment.image.repository="docker.eks.minlab.com/repository/docker-registry/$appName" -f Helm_Chart/values.yaml Helm_Chart/. --tiller-namespace cicd-tools --namespace cicd-tools
                  '''
              }
            }
        }
        stage('Compiling Selenium') {
            container('maven') {
              stage('Compiling Selenium') {
                  sh '''#!/bin/bash
                  git clone https://bitbucket.org/afernalc/webdrivertest.git && cd webdrivertest
                  appName=$(grep artifactId pom.xml | head -1 | cut -d '>' -f2 | cut -d '<' -f1)
                  appVersion=$(grep "<version>" pom.xml | head -1 | cut -d '>' -f2 | cut -d '<' -f1)
                  groupID=$(grep "groupId" pom.xml | head -1 | cut -d '>' -f2 | cut -d '<' -f1)
                  mvn clean install
                  mvn deploy:deploy-file -Dmaven.test.skip=true -Durl=http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/maven-snapshots/ -Dfile=target/${appName}-${appVersion}.jar -Dpackaging=jar -DgroupId=${groupID} -DartifactId=${appName} -Dversion=${appVersion}
                  '''
              }
            }
        }
        stage('Selenium Tests') {
            container('jdk') {
              stage('Selenium Tests') {
                  sh '''
                  apk --update add git curl
                  cd webdrivertest
                  appName=$(grep artifactId pom.xml | head -1 | cut -d '>' -f2 | cut -d '<' -f1)
                  groupID=$(grep "groupId" pom.xml | head -1 | cut -d '>' -f2 | cut -d '<' -f1)
                  appVersion=$(grep "<version>" pom.xml | head -1 | cut -d '>' -f2 | cut -d '<' -f1)
                  snapshotVersion=$(curl http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/maven-snapshots/${groupID}/${appName}/${appVersion}/maven-metadata.xml | grep -m 1 "<value>" | cut -d '>' -f2 | cut -d '<' -f1)
                  echo "webdriver_URL=http://selenium.eks.minlab.com/wd/hub" > data/mytest.properties
                  echo "XLSfilename=data/DATOS_TEST_1.xlsx" >> data/mytest.properties
                  curl -X GET http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/maven-snapshots/${groupID}/${appName}/${appVersion}/${appName}-${snapshotVersion}.jar --output ${appName}-${appVersion}.tgz
                  java -Dproperties_file="data/mytest.properties" -classpath ${appName}-${appVersion}.jar testlauncher.seleniumtest.TestLauncher
                  '''
              }
            }
        }
    }
}
