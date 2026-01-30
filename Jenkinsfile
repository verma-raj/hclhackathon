pipeline {
    agent any

    
    environment {
        
        AWS_REGION   = 'us-east-1'
        ACCOUNT_ID   = '762682309545'                
        REPO         = 'hackathon'                   

        IMAGE_NAME = '762682309545.dkr.ecr.us-east-1.amazonaws.com/hackathon'
        IMAGE_TAG  = "${env.BUILD_NUMBER}"   // e.g. 1,2
    }


    stages {
        stage('Git Checkout') {
            steps{
                sh''' echo "Checkout the code"'''
                checkout scmGit(branches: [[name: '*/Main']], extensions: [], userRemoteConfigs: [[credentialsId: 'c39f63b9-98be-4554-b22f-ed32b67788d2', url: 'https://github.com/verma-raj/hclhackathon.git']])
            }
        }
        }
        stage('code Build'){
                 steps{
                sh '''
                    echo "==> Building Docker image"
                    docker build --no-cache -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker images | grep ${IMAGE_NAME}
                '''
            }
        
        stage('Sonar Scan') {
             steps{
                echo "mvn clean verify sonar:sonar"
             }
        }

        Stage(' Trivy Scan of Image'){
             steps{
                echo "Trivy Scan of Image"
             }
        }

        Stage(' AWS Login & Authentication'){
             steps{
                echo "Login to ECR"
                
                    sh '''
                    aws --version
                    aws ecr get-login-password --region ${AWS_REGION} \
                    | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                '''
             }
        }

        Stage(' Build push to ECR'){
             steps{
                echo "Login to ECR"
                
                    sh '''
                    aws --version
                    aws ecr get-login-password --region ${AWS_REGION} \
                    | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    '''
             }
        }

        
        steps {
                withAWS(region: "${AWS_REGION}", credentials: 'aws-creds-id') {
                sh '''
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                '''
        }

       stage('Code Deploy') {
        steps {
            echo "Code Deploy"
             }
       }
        }

    }
}
