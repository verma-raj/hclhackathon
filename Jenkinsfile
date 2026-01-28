pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'Hello World'
                checkout scmGit(branches: [[name: '*/Main']], extensions: [], userRemoteConfigs: [[credentialsId: 'c39f63b9-98be-4554-b22f-ed32b67788d2', url: 'https://github.com/verma-raj/hclhackathon.git']])
            }
        }
    }
}
