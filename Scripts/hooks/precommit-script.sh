#!/bin/bash

if ! command -v swiftlint 2>&1 >/dev/null
then

  echo "install swiftlint \(v0.0.57\) for pre-commit linting."
  exit 0
fi

if [ "$(swiftlint --version)" != "0.57.1" ]
then 
echo "swiftlint installed with incorrect version (`swiftlint --version`). Please use version 0.57.1 for pre-commit linting."
exit 0
fi
OIFS="$IFS"
IFS=$'\n'
FILE_LIST=($(git diff --cached --name-only | grep "\.swift$"))
IFS="$OIFS"

if [ -z "${FILE_LIST}" ]; then
  exit 0
fi

swiftlint lint --config .swiftlint.yml --strict "${FILE_LIST[@]}"
RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo -e "Swiftlint failed!\n   Fix issues above or run:\n\tswiftlint lint --fix $(printf "\"%s\" " "${FILE_LIST[@]}")"
  echo "Skip linting with '--no-verify'."
  exit 1
fi
echo "Swiftlint passed!"
 exit 1