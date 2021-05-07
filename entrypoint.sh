#!/bin/sh -l

DRY_RUN="$1"

git config --global user.email "devops@buda.com"
git config --global user.name "Buda CD"
git config pull.rebase true
git fetch origin
git pull origin

sendsync get template

templates=$(git status -s templates | cut -d' ' -f3 | cut -d'/' -f 2 | tr '\n' ',' | sed 's/,$//g')

git stash

for template in $(echo ${templates} | sed 's/,/ /g'); do
    if [ $DRY_RUN="false" ]; then 
        git branch ${template}
        git checkout ${template}
        git pull origin ${template}
        git stash apply
        git add templates/${template}
        git commit -m "(auto) Changes in ${template}"
        git push origin ${template}
        echo ${GITHUB_TOKEN} | gh auth login --with-token
        gh pr create -d --title "(auto) Publish template: ${template}." --body "Detected changes in template ${template}. Review this PR to approve."
        git stash
        git checkout master
    else 
        echo "DRY RUN: would have created PR for ${template}"
    fi
done
