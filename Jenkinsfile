podTemplate(label: 'jnlp-petclinic-front', serviceAccount: 'jenkins', slaveConnectTimeout: '600', containers: [
    containerTemplate(
            name: 'npm',
            image: 'npm',
            ttyEnabled: true,
            resourceLimitCpu: '1000m',
            resourceLimitMemory: '768Mi',
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
            name: 'docker',
            image: 'docker:18.09.7-dind',
            ttyEnabled: true,
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            privileged: true,
            envVars: [
                secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password')
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
            name: 'jmeter',
            image: 'justb4/jmeter',
            ttyEnabled: true,
            command: 'cat',
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            privileged: true,
            envVars: [
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
            ]
    )
],
    volumes: [
        emptyDirVolume(
            mountPath: '/var/lib/docker',
            memory: false
            ),
        configMapVolume(
            mountPath: '/etc/docker',
            configMapName: 'docker-daemon-cm'
            )

    ]
) {
    node('jnlp-petclinic-front') {
        stage('Checkout') {
            checkout scm
            container('npm') {
              stage('Unit tests') {
                  sh '''#!/bin/bash
                  export NG_CLI_ANALYTICS=ci
                  apt-get update
                  apt-get install -y chromium
                  cd /tmp && git clone https://github.com/overflow15/spring-petclinic-angular.git
                  git checkout develop
                  cd spring-petclinic-angular
                  npm uninstall -g angular-cli @angular/cli
                  npm cache clean --force
                  npm install -g @angular/cli@latest
                  npm install
                  npm i -D handlebars@4.5.0
                  npm test
                  '''
              }
              stage('Compiling') {
                  sh '''#!/bin/bash
                  ng build
                  npm publish --registry http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/npm
                  '''
              }
              stage('Sonar') {
                  sh '''
                  npm install -D sonarqube-scanner
                  appName=$(grep name package.json | awk -F\" '{print $4}')
                  appVersion=$(grep version package.json | awk -F\" '{print $4}')
                  sed -i "s/application_name/$appName/g" sonar-project.properties
                  sed -i "s/application_version/$appVersion/g" sonar-project.properties

              }
              stage('To Sonar') {
                  sh 'mvn sonar:sonar \
                      -Dsonar.projectKey=petclinic-rest \
                      -Dsonar.host.url=$SONAR_URL \
                      -Dsonar.login=$SONAR_USER \
                      -Dsonar.password=$SONAR_PASS'
              }
              stage('To Nexus') {
                  sh '#!/bin/bash \n' +
                  'mvn deploy:deploy-file \
                  -Dmaven.test.skip=true \
                  -Durl=http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/maven-releases/ \
                  -Dfile=target/spring-petclinic-rest-2.1.5.jar \
                  -Dpackaging=jar \
                  -DgroupId=spring-petclinic \
                  -DartifactId=rest \
                  -Dversion=$(date +%s)'
              }
            }
        }
        stage('Send Sonar data to InfluxDB') {
            container('python') {
              stage('Send Sonar data to InfluxDB') {
                  sh '''
                  python3 -m pip install influxdb
                  python /home/jenkins/agent/workspace/petclinic/python/qamera.py /home/jenkins/agent/workspace/petclinic/python/application.properties petclinic-rest
                  '''
              }
            }
        }
        stage('DinD') {
            container('docker') {
              stage('Docker Build') {
                  sh 'docker build -t petclinic:latest .'
              }
              stage('Docker tag and push') {
                  sh '''
                  tag_nexus=$(date +%s) && docker tag petclinic:latest docker.eks.minlab.com/repository/docker-registry/petclinic:${tag_nexus}
                  docker login http://docker.eks.minlab.com -uadmin -p$(echo -ne $NEXUS_ADMIN_PASS)
                  docker push docker.eks.minlab.com/repository/docker-registry/petclinic:${tag_nexus}
                  '''
              }
            }
        }
        stage('Deploy') {
            container('helm') {
              stage('Helm upgrade') {
                  sh '''#!/bin/bash
                  image_tag=$(curl -u admin:$(echo -ne $NEXUS_ADMIN_PASS) -X GET http://nexus.eks.minlab.com/service/rest/v1/search/ | grep path | grep docker | awk -F'"' '{print $4}' | awk -F/ '{print $6}' | sort -nr | head -1)
                  helm upgrade --install --force petclinic-rest --set-string deployment.image.tag=$(echo $image_tag) -f Helm_Chart/values.yaml Helm_Chart/. --tiller-namespace cicd-tools --namespace cicd-tools
                  '''
              }
            }
        }
        stage('Perf Test') {
            container('jmeter') {
              stage('jMeter test') {
                  sh '''
                  sleep 60
                  until [ $(curl -o /dev/null --silent --head --write-out '%{http_code}\n' http://petclinicrest.eks.minlab.com/petclinic/swagger-ui.html) -eq 200 ] ;do echo "Initializing application..." ;sleep 5 ;done
                  cp /home/jenkins/agent/workspace/petclinic/tests/influxDBConnector/* /opt/apache-jmeter-5.1.1/lib/ext/
                  /opt/apache-jmeter-5.1.1/bin/jmeter.sh -Dlog_level.jmeter=DEBUG -JV_PC_HOST="petclinicrest.eks.minlab.com" -JV_PC_PORT="80" -JV_ESCENARIO="PETCLINIC_REST" -JV_SISTEMA="PETCLINIC_REST" -JV_NUM_THREADS="2" -JV_GUARDAR_EN_INFLUXDB="SI" -JV_DURATION_SECONDS="30" -JV_RAMP_UP_SECONDS="2" -JV_PRUEBA_FUNCIONAL="SI" -JV_INFLUX_URL="http://influxdb:8086" -JV_INFLUX_USER="admin" -JV_INFLUX_PASSWD="" -JV_DATABASE_PERF_TEST="perf_test" -JV_DATABASE_FUNC_TEST="func_test" -n -t /home/jenkins/agent/workspace/petclinic/tests/test-plan.jmx -l /home/jenkins/agent/workspace/petclinic/tests/test-plan.jtl -j /home/jenkins/agent/workspace/petclinic/tests/jmeter.log -e -o /home/jenkins/agent/workspace/petclinic/tests/log/
                  '''
              }
            }
        }

    }
}
