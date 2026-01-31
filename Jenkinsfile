node(''){
  env.PATH = "${env.WORKSPACE}/aws-bin:${env.PATH}"
 
  def dockerImage = "762682309545.dkr.ecr.us-east-1.amazonaws.com/hackathon:${env.BUILD_NUMBER}"
  def awsExists = sh(script: "command -v aws >/dev/null 2>&1", returnStatus: true) == 0
                      // Check if the Trivy Docker image is available
                    def trivyImage = 'aquasec/trivy:latest'
                    def trivyContainerName = 'trivy-container'
                    
  if (!awsExists) { 
      stage('Install AWS CLI') {
        sh '''
          set -e
          if [ ! -x "$WORKSPACE/aws-bin/aws" ]; then
            rm -rf aws awscliv2.zip
            curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
            unzip -oq awscliv2.zip
            ./aws/install \
              --install-dir "$WORKSPACE/aws-cli" \
              --bin-dir "$WORKSPACE/aws-bin"
            rm -rf aws awscliv2.zip
          fi

          aws --version
        '''
      }
  }
  stage('Git Checkout') {
        sh''' echo "Checkout the code"'''
        checkout scm
  } 
  stage("build app") {
      echo "compile the project"
  }

  stage('Build docker image') {
      dir('infra'){
          
          echo "==> Building Docker image"
          sh script: "docker build -t ${dockerImage} -f Dockerfile ."
          echo "==> Completed building Docker image"
      }
  }

  
withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
        stage('SonarQube Analysis') {
            echo 'Running SonarQube scan using Docker...'
            sh '''
                docker run --rm \
                    -v $(pwd):/project \
                    -e SONAR_TOKEN=$SONAR_TOKEN \
                    sonarsource/sonar-scanner-cli \
                    sonar-scanner \
                    -Dsonar.projectKey=hclhackathon \
                    -Dsonar.sources=. \
                    -Dsonar.host.url=http://34.231.5.233:9000 \
                    -Dsonar.token=$SONAR_TOKEN
            '''
        }
    }



        stage('Run Trivy Scan') {
                    // Run the Trivy scan in the container
                    echo "Running Trivy scan on the Docker image"
                    sh """
                    docker run \
                            --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v ${WORKSPACE}:/workspace \
                            ${trivyImage} image --format json ${dockerImage} > trivy-report.json
                    """
                    // Archive the Trivy scan report
                    archiveArtifacts artifacts: '**/trivy-report.json', allowEmptyArchive: true
        }


  stage('Publish to ECR') {
    withAWS(credentials: 'aws-creds', region: 'us-east-1') {
      sh '''
        aws ecr get-login-password --region us-east-1 \
        | docker login --username AWS --password-stdin 762682309545.dkr.ecr.us-east-1.amazonaws.com
      '''
      sh script: "docker push ${dockerImage}", label: "Push to ECR"
    }
  }

}
