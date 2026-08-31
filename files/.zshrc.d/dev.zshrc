alias aws="/usr/bin/aws --no-cli-pager"
alias code="/usr/bin/code --disable-accelerated-video-decode -n"

export TERRAFORM_VERSION=1.12.2

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

tf-do () {
  local action=''
  local aws_profile=''
  local dir='.'
  local init=false
  local targets=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --action=*) action="${1#*=}"; shift ;;
      --action) action="$2"; shift 2 ;;
      --aws-profile=*) aws_profile="${1#*=}"; shift ;;
      --aws-profile) aws_profile="$2"; shift 2 ;;
      --dir=*) dir="${1#*=}"; shift ;;
      --dir) dir="$2"; shift 2 ;;
      --init) init=true; shift ;;
      --target=*) targets+=("${1#*=}"); shift ;;
      --target) targets+=("$2"); shift 2 ;;
      --) shift; break ;;
      *) shift ;;
    esac
  done

  if [ -z "$action" ]; then
    echo "No action given." >&2
    return $LINENO
  fi

  if [[ "$action" != "plan" && "$action" != "apply" && "$action" != "destroy" ]]; then
    echo "Action must be one of 'plan', 'apply', or 'destroy'." >&2
    return $LINENO
  fi

  if [ -z "$aws_profile" ]; then
    echo "No AWS profile given." >&2
    return $LINENO
  fi

  if [ ! -d "$dir" ]; then
    echo "Path '$dir' does not exist or is not a directory." >&2
    return $LINENO
  fi

  export AWS_PROFILE="$aws_profile"

    if [[ "$init" == true ]]; then
    rm -rf "${dir}/.terraform/modules"
    AWS_PROFILE=$aws_profile terraform -chdir="$dir" init
  fi

  args=()
  for target in "${targets[@]}"; do
    args+=("-target" "$target")
  done

  AWS_PROFILE=$aws_profile terraform -chdir="$dir" "$action" "${args[@]}"
}

tf-plan () {    tf-do --action=plan    --dir="$2" --aws-profile="$1" "$([ -n "$3" ] && echo -n '--init' || echo -n)"; }
tf-apply () {   tf-do --action=apply   --dir="$2" --aws-profile="$1" "$([ -n "$3" ] && echo -n '--init' || echo -n)"; }
tf-destroy () { tf-do --action=destroy --dir="$2" --aws-profile="$1" "$([ -n "$3" ] && echo -n '--init' || echo -n)"; }

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
