*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1
Test Setup    Workaround

*** Test Cases ***

Service status
    Cumulocity.Should Have Services    name=tedge-agent    service_type=service    status=up

*** Keywords ***

Workaround
    # WORKAROUND: Restart child device to ensure service status is updated
    ${operation}=    Cumulocity.Restart Device
    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}
