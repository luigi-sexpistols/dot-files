slugify () {
  echo "$1" \
  | sed -E 's/ & / and /g' \
  | sed 's/²/2/g' \
  | sed -E 's/[^a-zA-Z0-9]/_/g' \
  | sed -E 's/_{2,}/_/g' \
  | sed -E 's/^_//g' \
  | sed -E 's/_$//g' \
  | tr '[:upper:]' '[:lower:]'
}
