alias aws="/usr/bin/aws --no-cli-pager"
alias code="/usr/bin/code --disable-accelerated-video-decode -n"

# alias terraform-docs to docker
function terraform-docs () {
  if [ "$1" != "" ]; then
    working_dir="$1"
  else
    working_dir="$(pwd)"
  fi

  docker run \
    --rm \
    --volume "${working_dir}:/terraform-docs" \
    --user "$(id -u):$(id -g)" \
    quay.io/terraform-docs/terraform-docs:latest markdown /terraform-docs
}

function terraform-do() {
  aws_profile="$1"
  dir="$2"
  action="${3:-plan}"
  skip_init="${4:-false}"

  if [ -z "$aws_profile" ] || [ -z "$dir" ]; then
      echo "Usage: terraform-apply <aws_profile> <dir>"
      return 1
  fi

  if [ ! -d "$dir" ]; then
      echo "Directory '$dir' does not exist."
      return 1
  fi

  if [[ "$skip_init" == "false" ]]; then
    rm -rf "${dir}/.terraform"
    AWS_PROFILE="$aws_profile" terraform -chdir="$dir" init
  fi

  AWS_PROFILE="$aws_profile" terraform -chdir="$dir" "$action"
}

function terraform-plan () {
  terraform-do "$1" "$2" plan "$3"
}

function terraform-apply () {
  terraform-do "$1" "$2" apply "$3"
}

function aws-login () {
    local profile="${1:-default}"

    /usr/bin/aws sso login --profile="$profile"
}

function multi-git () {
    local repos=()
    local command=()

    eval set -- "$(getopt --long='repo:,command:' --name "$0" -- '' "$@")"

    while true; do
        case "$1" in
            --repo) repos+=("$2"); shift 2 ;;
            --command) command=($2); shift 2 ;;
            --) shift; break ;;
            *) break ;;
        esac
    done

    for repo in "${repos[@]}"; do
        echo "Repository: $repo"
        echo

        [ ! -d "$repo" ] \
            && echo "Repository '${repo}' does not exist, skipping." \
            && continue

#         git -C "$repo" "${command[@]}"
        git -C "$repo" fc 58

        echo
        echo "--------------------"
        echo
    done
}
