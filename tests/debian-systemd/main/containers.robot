*** Settings ***
Resource    ../../resources/common.resource
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Main Device

*** Test Cases ***

Pull docker.io images by default
    ${operation}=    Cumulocity.Execute Shell Command    sudo podman pull nginx
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
