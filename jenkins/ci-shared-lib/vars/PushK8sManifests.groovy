def call(String workdir, String imageTag, String gitRepoUrl, String branchName) {
    dir(workdir) {
        def cleanUrl = gitRepoUrl.replace("https://", "")
        sh """
            echo "Pushing updated manifests to ${cleanUrl} on branch ${branchName}"
            git config user.email "jenkins@clouddevops.com"
            git config user.name "jenkins"
            git add .
            git commit -m "Update image to ${imageTag}" || true
            git push https://${GIT_USER}:${GIT_PASS}@${cleanUrl} HEAD:${branchName}
        """
    }
}