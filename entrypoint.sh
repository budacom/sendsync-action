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

set -o nounset
set -o pipefail

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help               Display help
    -m, --mode               The mode in which to run the action (one of: sync, apply)
    -d, --dry-run            Run the action with dry-run
    --committer-email        The email to use when creating the commits
    --committer-name         The name to use when creating the commits
    --draft-pr               Create the pull request as draft

EOF
}

main() {
    local mode=
    local dry_run=false
    local committer_email=
    local committer_name=
    local draft_pr=false

    parse_command_line $@

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
            -m|--mode)
                if [[ -n "${2:-}" ]]; then
                    mode="$2"
                    shift
                else
                    echo "ERROR: '-m|--mode' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -d|--dry-run)
                if [[ -n "${2:-}" ]]; then
                    dry_run="$2"
                    shift
                else
                    echo "ERROR: '-d|--dry-run' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --committer-email)
                if [[ -n "${2:-}" ]]; then
                    committer_email="$2"
                    shift
                else
                    echo "ERROR: '--committer-email' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --committer-name)
                if [[ -n "${2:-}" ]]; then
                    committer_name="$2"
                    shift
                else
                    echo "ERROR: '--committer-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
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

    if [[ $mode = 'sync' ]]; then
        if [[ -z "$committer_name" ]]; then
            echo "ERROR: '--committer-name' is required on sync mode" >&2
            show_help
            exit 1
        fi

        if [[ -z "$committer_email" ]]; then
            echo "ERROR: '--committer-email' is required on sync mode" >&2
            show_help
            exit 1
        fi
    fi
}

sync() {
    setup_git

    echo "Running in syncronization mode"
    sendsync get template

    templates=$(get_changed_templates_on_workdir templates)

    for template in $templates; do
        echo "Stashing $template..."
        git add -A templates/$template
        git stash push -m $template -- templates/$template
    done

    git stash list | while read line; do
        stashed_template=$(git stash list | grep "stash@{0}" | cut -d' ' -f4)

        if [ $dry_run = "false" ]; then
            echo "Creating PR for $stashed_template..."
            create_pr_for_template $stashed_template
        else
            echo "DRY RUN: would have created PR for ${stashed_template}"
        fi
    done
}

apply() {
    setup_git

    echo "Running in apply mode"
    templates=$(get_changed_templates_on_commit templates HEAD~1 $GITHUB_SHA)

    for template in ${templates}; do
        if [ $dry_run = "false" ]; then
            sendsync apply -f templates/${template}/template.json
        else
            echo "DRY RUN: would have applied ${template}"
        fi
    done
}

setup_git() {
    git config --global --add safe.directory /github/workspace
    git pull --unshallow
    git config --global user.email $committer_email
    git config --global user.name $committer_name
    git fetch origin
    git merge origin/master
}

get_changed_templates_on_workdir() {
    local templates_path=$1

    git status -s $templates_path | cut -d'/' -f 2 | sort | uniq
}

get_changed_templates_on_commit() {
    local templates_path=$1
    local base_commit=$2
    local commit=$3

    git diff --name-only -m $commit $base_commit $templates_path | cut -d'/' -f 2 | sort | uniq
}

create_pr_for_template() {
    local template=$1
    local template_path=templates/$template
    local branch=$template

    if ! git branch -r | grep -q $template; then
        git branch $branch
    fi
    git checkout $branch

    git stash pop
    git add $template_path
    git commit -m "(auto) Changes in $template"
    git push origin $branch

    echo ${GITHUB_TOKEN} | gh auth login --with-token
    gh pr create -d --title "(auto) Publish template: $template." --body "Detected changes in template $template. Review this PR to approve."

    git checkout master
}

main "$@"