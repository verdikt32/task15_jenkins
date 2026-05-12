pipeline {
    agent any

    environment {
        REGISTRY        = "ghcr.io"
        GITHUB_USER     = "verdikt32" 
        IMAGE_NAME      = "nginx-web-app"            
        DEV_SERVER      = "18.206.98.217"             
        PROD_SERVER     = "54.163.118.83"            
        DEV_PORT        = "8080"
        PROD_PORT       = "8080"
        APP_PORT        = "80"
    }

    options {
        buildDiscarder(logRotator(
            numToKeepStr: '10',
            daysToKeepStr: '30'
        ))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Set Image Tag') {
            steps {
                script {
                    def branch = env.BRANCH_NAME
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

                    if (branch == 'main') {
                        env.ENV_NAME  = 'prod'
                        env.SSH_KEY   = 'ssh-key'
                        env.SERVER    = env.PROD_SERVER
                        env.HOST_PORT = env.PROD_PORT
                    } else if (branch == 'dev') {
                        env.ENV_NAME  = 'dev'
                        env.SSH_KEY   = 'ssh-key'
                        env.SERVER    = env.DEV_SERVER
                        env.HOST_PORT = env.DEV_PORT
                    } else {
                        error("Branch '${branch}' не поддерживается пайплайном")
                    }

                    env.IMAGE_TAG = "${REGISTRY}/${GITHUB_USER}/${IMAGE_NAME}:${env.ENV_NAME}-${shortSha}-${env.BUILD_NUMBER}"
                    echo "Image tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t $IMAGE_TAG .'
            }
        }

        stage('Push to GHCR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ghcr-credentials',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh '''
                        echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
                        docker push $IMAGE_TAG
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(["${env.SSH_KEY}"]) {
                    withCredentials([usernamePassword(
                        credentialsId: 'ghcr-credentials',
                        usernameVariable: 'GHCR_USER',
                        passwordVariable: 'GHCR_TOKEN'
                    )]) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no ubuntu@$SERVER \
                                "echo $GHCR_TOKEN | docker login ghcr.io -u $GHCR_USER --password-stdin &&
                                docker pull $IMAGE_TAG &&
                                docker stop app-$ENV_NAME || true &&
                                docker rm   app-$ENV_NAME || true &&
                                docker run -d \
                                    --name app-$ENV_NAME \
                                    --restart unless-stopped \
                                    -p $HOST_PORT:$APP_PORT \
                                    $IMAGE_TAG"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                sh 'docker rmi $IMAGE_TAG || true'
                sh 'docker image prune -f'
                cleanWs()
            }
        }
        success {
            echo "✅ Deployed ${env.IMAGE_TAG} to ${env.ENV_NAME}"
        }
        failure {
            echo "❌ Pipeline failed on branch: ${env.BRANCH_NAME}"
        }
    }
}