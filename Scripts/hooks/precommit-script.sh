#!/bin/bash

OIFS="$IFS"
IFS=$'\n'
FILE_LIST=($(git diff --cached --name-only | grep "\.swift$"))
IFS="$OIFS"

if [ -z "${FILE_LIST}" ]; then
  exit 0
fi

if [ -e $(command -v swiftlint 2>&1 >/dev/null) ] && [ "$(swiftlint --version)" == "0.57.1" ]
then
  swiftlint lint --config .swiftlint.yml --strict "${FILE_LIST[@]}"
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo -e "Swiftlint failed!\n   Fix issues above or run:\n\tswiftlint lint --fix $(printf "\"%s\" " "${FILE_LIST[@]}")"
    echo "Skip linting with '--no-verify'."
    exit 1
  fi
  echo "Swiftlint passed!"
else 
  echo "Install SwiftLint at version 0.57.1 to enable pre-commit linting."
fi 

if [ -e $(command -v swiftformat 2>&1 > /dev/null) ]; then 
  swiftformat --lint "${FILE_LIST[@]}"
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo -e "Swiftformat linting failed.\n Fix the issues above or run:\n\tswiftformat $(printf "\"%s\" " "${FILE_LIST[@]}")"
    echo "Skip linting with '--no-verify'."
    exit 1
  fi
  echo "SwiftFormat passed!"
else
  echo "Install swiftformat to enable pre-commit format linting."
fi 