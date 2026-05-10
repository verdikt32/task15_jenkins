pipeline {
    agent any

    environment {
        REGISTRY        = "ghcr.io"
        GITHUB_USER     = "verdikt32"        // замени
        IMAGE_NAME      = "nginx-web-app"               // замени
        DEV_SERVER      = "54.82.206.167"               // замени
        PROD_SERVER     = "3.94.206.128"              // замени
        DEV_PORT        = "8080"
        PROD_PORT       = "8080"
        APP_PORT        = "3000"                        // порт внутри контейнера
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
                sh "docker build -t ${env.IMAGE_TAG} ."
            }
        }

        stage('Push to GHCR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ghcr-credentials',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh """
                        echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin
                        docker push ${env.IMAGE_TAG}
                    """
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent([env.SSH_KEY]) {
                    withCredentials([usernamePassword(
                        credentialsId: 'ghcr-credentials',
                        usernameVariable: 'GHCR_USER',
                        passwordVariable: 'GHCR_TOKEN'
                    )]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ubuntu@${env.SERVER} '
                                echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin &&
                                docker pull ${env.IMAGE_TAG} &&
                                docker stop app-${env.ENV_NAME} || true &&
                                docker rm   app-${env.ENV_NAME} || true &&
                                docker run -d \
                                    --name app-${env.ENV_NAME} \
                                    --restart unless-stopped \
                                    -p ${env.HOST_PORT}:${APP_PORT} \
                                    ${env.IMAGE_TAG}
                            '
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Удаляем локальный образ после пуша
                sh "docker rmi ${env.IMAGE_TAG} || true"

                // Чистим dangling images (слои без тега)
                sh "docker image prune -f"

                // Чистим workspace
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
