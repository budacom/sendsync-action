#!/bin/sh -l

set -x

DRY_RUN="$1"
MODE="$2"

alias tpl_path_join="cut -d'/' -f 2 | sort | uniq"
git config --global user.email "devops@buda.com"
git config --global user.name "Buda CD"
git config pull.rebase true
git fetch origin
git merge origin/master

if [ $MODE = "sync" ]; then

    sendsync get template

    templates=$(git status -s templates | cut -d' ' -f3 | tpl_path_join)

    git stash

    for template in $(echo ${templates}); do
        if [ $DRY_RUN = "false" ]; then 
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
elif [ $MODE = "apply" ]; then
    git pull origin master
    git diff --name-only ${GITHUB_SHA} HEAD~1 templates/
    templates=$(git diff --name-only ${GITHUB_SHA} HEAD~1 templates/ | tpl_path_join)
    for template in ${templates}; do
        if [ $DRY_RUN = "false" ]; then 
            sendsync apply templates/${template}/template.json
        else 
            echo "DRY RUN: would have applied ${template}"
        fi
    done
else 
    echo "Mode ${MODE} not supported"
    exit 1
fi