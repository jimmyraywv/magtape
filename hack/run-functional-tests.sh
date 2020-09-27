#!/usr/bin/env bash

# Copyright 2020 T-Mobile, USA, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Trademark Disclaimer: Neither the name of T-Mobile, USA, Inc. nor the names of
# its contributors may be used to endorse or promote products derived from this
# software without specific prior written permission.

################################################################################
#### Variables, Arrays, and Hashes #############################################
################################################################################

RUN_TYPE="${1}"
TEST_RESOURCE_KIND="${2}"
TEST_RESOURCE_DESIRED="${3}"
TEST_NAMESPACE="${4}"
TESTS_MANIFEST="testing/functional-tests.yaml"

################################################################################
#### Functions #################################################################
################################################################################

# **********************************************
# Check the argument being passed to script
# **********************************************
help_message() {

  echo "You need to specify the proper arguments:"
  echo "    Actions Type: (\"test\" or \"clean\")"
  echo "    Test Resource Type: (\"all\", or \"deployments\", \"pdbs\", \"statefulsets\", etc.)"
  echo "    Test Type: (\"all\", \"pass\", or \"fail\")"
  echo "    Test Namespace: (\"test1\")"

}

# **********************************************
# Check the argument being passed to script
# **********************************************
check_arguments() {

  if [ "${RUN_TYPE}" == "" ] || [ "${TEST_RESOURCE_KIND}" == "" ] || [ "${TEST_RESOURCE_DESIRED}" == "" ] || [ "${TEST_NAMESPACE}" == "" ]; then

    help_message
    exit 1

  elif [ "${RUN_TYPE}" != "test" ] && [ "${RUN_TYPE}" != "clean" ]; then 

    help_message
    exit 1

  elif [ "${TEST_RESOURCE_DESIRED}" != "pass" ] && [ "${TEST_RESOURCE_DESIRED}" != "fail" ] && [ "${TEST_RESOURCE_DESIRED}" != "all" ]; then

    help_message
    exit 1

  fi

}

# **********************************************
# Run tests/cleanup
# **********************************************
run_resource_tests() {
  
  #define local action from first argument
  local action="${1}"

  #define local index from second argument
  local resource_index="${2}"

  #grab local resource from ${TESTS_MANIFEST}
  local resource
  
  resource=$(yq read "${TESTS_MANIFEST}" "resources.[${resource_index}].kind")

  #grab local test type from ${TESTS_MANIFEST}
  local test_type
  
  test_type=$(yq read "${TESTS_MANIFEST}" "resources.[${resource_index}].desired")

  #grab local list of test manifests to use
  local manifest_list
  
  manifest_list=$(yq read -P "${TESTS_MANIFEST}" "resources.[${resource_index}].manifests" | sed 's/^-[ ]*//')

  if [ "${manifest_list}" == "" ]; then

    echo "[WARN] No \"${test_type}\" tests for \"${resource}\". Skipping..."
    echo "============================================================================"

  else

    echo "[INFO] **** Running \"${test_type}\" tests for \"${resource}\" ****"
    echo "============================================================================"

    for testfile in ${manifest_list}; do

        local test_file_path="testing/${resource}/${testfile}"

        if [ -f "${test_file_path}" ]; then

            echo "[INFO] ${action}: \"${testfile}\""
            
            if [ "${action}" == "delete" ]; then
              
              # kubectl doesn't like double quites here. disable checking for double quotes around variables
              # shellcheck disable=SC2086
              kubectl ${action} -f "${test_file_path}" -n ${TEST_NAMESPACE} --ignore-not-found

            else

              # kubectl doesn't like double quites here. disable checking for double quotes around variables
              # shellcheck disable=SC2086
              kubectl ${action} -f "${test_file_path}" -n ${TEST_NAMESPACE}

            fi

            local exit_code=$?

            if [ "${action}" == "apply" ]; then

                if [ "${test_type}"  == "pass" ] && [ ${exit_code} -ne 0 ]; then

                    echo "[ERROR] Test did not pass. Exiting..."
                    exit 1

                elif [ "${test_type}"  == "fail" ] && [ ${exit_code} -ne 1 ]; then

                    echo "[ERROR] Test did not pass. Exiting..."
                    exit 1

                else

                    echo "[INFO] Test Passed"

                fi

            fi

        else

            echo "[WARN] File \"${test_file_path}\" not found. Skipping..."

        fi

        echo "============================================================================"
        
    done

  fi

}

# **********************************************
# Determine test scope
# **********************************************
scope_and_run_tests() {

  #create identifiable local variable for argument 1, the action to perform
  local action="${1}"

  #size the array of resources
  local resource_array_length
  resource_array_length=$(yq read -l "${TESTS_MANIFEST}" 'resources')


  #loop through all resources in the supplied manifest
    #determine which indicies meet the supplied criteria in ${TEST_RESOURCE_KIND} and ${TEST_RESOURCE_DESIRED}
  for ((i = 0 ; i < resource_array_length ; i++)); do

    #check if we're doing all resources or if the resource kind at $i matches the requested kind
    #double brackets are technically correct; the BEST kind of correct!
    if [[ "${TEST_RESOURCE_KIND}" == "all" ]] || [[ "${TEST_RESOURCE_KIND}" == $(yq read "${TESTS_MANIFEST}" "resources.[${i}].kind") ]]; then

      #check if we're doing all desired results or if the resoured desired result at $i matches the requested desired result
      if [[ "${TEST_RESOURCE_DESIRED}" == "all" ]] || [[ "${TEST_RESOURCE_DESIRED}" == $(yq read "${TESTS_MANIFEST}" "resources.[${i}].desired") ]]; then

        #indexes_to_process+=("${i}")

        run_resource_tests "${action}" "${i}"
      fi

    fi

  done

  #echo ${indexes_to_process[@]}

}

################################################################################
#### Main ######################################################################
################################################################################

check_arguments

case ${RUN_TYPE} in 

  test)
      scope_and_run_tests "apply"
      ;;
  clean)
      scope_and_run_tests "delete"
      ;;
       *)
      help_message
      ;; 
esac

