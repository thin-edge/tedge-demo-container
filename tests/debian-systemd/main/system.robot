*** Settings ***
Resource    ../../resources/common.resource

Suite Setup    Setup Device
Suite Teardown    Collect Logs

*** Test Cases ***

SSH daemon should be running by default
    ${operation}=    Cumulocity.Execute Shell Command    sudo systemctl is-active ssh
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}

Test user should be present by default
    ${operation}=    Cumulocity.Execute Shell Command    grep -q iotadmin /etc/passwd
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
