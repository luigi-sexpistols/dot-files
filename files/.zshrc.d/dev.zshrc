alias aws="/usr/bin/aws --no-cli-pager"

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

function aws-login () {
    local profile="${1:-default}"

    /usr/bin/aws sso login --profile="$profile"
}
