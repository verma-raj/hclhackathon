pipeline {
    agent any

    stages {
        stage('Git Checkout') {
            steps {
                sh''' echo "Checkout the code"'''
                checkout scmGit(branches: [[name: '*/Main']], extensions: [], userRemoteConfigs: [[credentialsId: 'c39f63b9-98be-4554-b22f-ed32b67788d2', url: 'https://github.com/verma-raj/hclhackathon.git']])
            }
        }
        stage('code Build'){

        }
        
        stage('Sonar Scan') {
                mvn clean verify sonar:sonar
        }

        Stage(' Trivy Scan of Image'){

        }

        Stage(' Code Push to ECR'){

        }
        

        stage('Code Deploy'){

        }

    }
}
