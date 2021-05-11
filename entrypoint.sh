#!/usr/bin/env bash

# Copyright Buda.com.SpA
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help               Display help
    -m, --mode               The mode in which to run the action (one of: sync, apply)
    -d, --dry-run            Run the action with dry-run

EOF
}

main() {
    local mode=
    local dry_run=false

    parse_command_line "$@"

    if [[ $mode = "sync" ]]; then
        sync
    elif [[ $mode = "apply" ]]; then
        apply
    fi

    echo $mode
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -d|--mode)
                if [[ -n "${2:-}" ]]; then
                    mode="$2"
                    shift
                else
                    echo "ERROR: '-m|--mode' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -u|--dry-run)
                dry_run=true
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$mode" ]]; then
        echo "ERROR: '-m|--mode' is required." >&2
        show_help
        exit 1
    fi

    if [[ ! "$mode" =~ ^(sync|apply)$ ]]; then
        echo "ERROR: '$mode mode is not supported." >&2
        show_help
        exit 1
    fi
}

sync() {
    setup_git

    echo "Running in syncronization mode"
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
}

apply() {
    setup_git

    echo "Running in apply mode"

    git pull --unshallow
    git diff --name-only ${GITHUB_SHA} HEAD~1 templates/
    templates=$(git diff --name-only -m ${GITHUB_SHA} HEAD~1 templates/ | tpl_path_join)
    for template in ${templates}; do
        if [ $DRY_RUN = "false" ]; then
            sendsync apply -f templates/${template}/template.json
        else
            echo "DRY RUN: would have applied ${template}"
        fi
    done
}

setup_git() {
    alias tpl_path_join="cut -d'/' -f 2 | sort | uniq"
    git config --global user.email "devops@buda.com"
    git config --global user.name "Buda CD"
    git config pull.rebase true
    git fetch origin
    git merge origin/master
}


main "$@"