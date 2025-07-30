# todo - use long option names (--volume instead of -v, etc.)

# alias aws to docker
alias aws="docker run -it --rm -v '${HOME}/.aws:/root/.aws' amazon/aws-cli --no-cli-pager"

# alias terraform-docs to docker
function terraform-docs () {
  if [ "$1" != "" ]; then
    working_dir="$1"
  else
    working_dir="$(pwd)"
  fi

  docker run --rm --volume "${working_dir}:/terraform-docs" -u "$(id -u)" quay.io/terraform-docs/terraform-docs:latest markdown /terraform-docs
}
