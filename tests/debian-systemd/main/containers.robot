*** Settings ***
Resource    ../../resources/common.resource

Suite Setup    Setup Device
Suite Teardown    Collect Logs

*** Test Cases ***

Pull docker.io images by default
    ${operation}=    Cumulocity.Execute Shell Command    sudo podman pull nginx
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
