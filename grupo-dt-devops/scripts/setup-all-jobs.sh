#!/usr/bin/env bash
set -euo pipefail

: "${JENKINS_URL:?Define JENKINS_URL}"
: "${JENKINS_USER:?Define JENKINS_USER}"
: "${JENKINS_TOKEN:?Define JENKINS_TOKEN}"

create_job() {
  local name="$1"
  local jenkinsfile="$2"

  cat > /tmp/config.xml <<XML
<flow-definition plugin="workflow-job">
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>REPLACE_WITH_GIT_REPO_URL</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec><name>*/main</name></hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>${jenkinsfile}</scriptPath>
    <lightweight>true</lightweight>
  </definition>
</flow-definition>
XML

  curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" -X POST \
    "$JENKINS_URL/createItem?name=$name" \
    -H "Content-Type: application/xml" \
    --data-binary @/tmp/config.xml

  echo "Creado job: $name"
}

create_job "AWS-UFV-CloudFormation-Deploy" "jenkins/Jenkinsfile-infra"
create_job "AWS-UFV-Ansible-Inventory-Build" "jenkins/Jenkinsfile-inventory"
create_job "AWS-UFV-Ansible-App-Deploy" "jenkins/Jenkinsfile-provision"
create_job "AWS-UFV-Ansible-Web-Deploy" "jenkins/Jenkinsfile-webdeploy"
