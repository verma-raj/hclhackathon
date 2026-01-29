pipeline {
    agent any

    
    environment {
        
        AWS_REGION   = 'ap-south-1'
        ACCOUNT_ID   = '123456789012'                 // ← change
        REPO         = 'your-repo'                    // ← change

        IMAGE_NAME = '762682309545.dkr.ecr.us-east-1.amazonaws.com/hackathon'
        IMAGE_TAG  = "${env.BUILD_NUMBER}"   // e.g. 42
    }


    stages {
        stage('Git Checkout') {
            
                sh''' echo "Checkout the code"'''
                checkout scmGit(branches: [[name: '*/Main']], extensions: [], userRemoteConfigs: [[credentialsId: 'c39f63b9-98be-4554-b22f-ed32b67788d2', url: 'https://github.com/verma-raj/hclhackathon.git']])
            }
        }
        stage('code Build'){
                
                sh '''
                    echo "==> Building Docker image"
                    docker build --pull --no-cache -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker images | grep ${IMAGE_NAME}
                '''

        }
        
        stage('Sonar Scan') {
                echo "mvn clean verify sonar:sonar"
        }

        Stage(' Trivy Scan of Image'){
                echo "Trivy Scan of Image"
        }

        Stage(' AWS Login & Authentication'){
                echo "Login to ECR"
                
                    sh '''
                    aws --version
                    aws ecr get-login-password --region ${AWS_REGION} \
                    | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                '''
        }

        Stage(' Build push to ECR'){
                echo "Login to ECR"
                
                    sh '''
                    aws --version
                    aws ecr get-login-password --region ${AWS_REGION} \
                    | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    '''
        }

        
        steps {
                withAWS(region: "${AWS_REGION}", credentials: 'aws-creds-id') {
                sh '''
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                '''
        }

        

        stage('Code Deploy') {
            echo "Code Deploy"
        }

    }
}
