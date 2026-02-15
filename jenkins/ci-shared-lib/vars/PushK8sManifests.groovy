def call(String workdir, String imageTag) {
    dir(workdir) {
        sh """
            echo "Pushing updated manifests to GitHub"
            git config user.email "jenkins@clouddevops.com"
            git config user.name "jenkins"
            git add .
            git commit -m "Update image to ${imageTag}" || true
            git push https://${GIT_USER}:${GIT_PASS}@github.com/therealqi/clouddevopsgradproject.git HEAD:main
            echo "Manifests pushed successfully"
        """
    }
}