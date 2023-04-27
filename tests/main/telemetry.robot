*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Main Device

*** Test Cases ***

Child devices should be attached to the main device
    Cumulocity.Should Be A Child Device Of Device    ${CHILD_DEVICE_1}
    Cumulocity.Should Be A Child Device Of Device    ${CHILD_DEVICE_2}

Service status
    Cumulocity.Should Have Services    name=tedge-mapper-c8y    service_type=service    status=up
    Cumulocity.Should Have Services    name=tedge-mapper-collectd    service_type=service    status=up
    Cumulocity.Should Have Services    name=tedge-agent    service_type=service    status=up
    Cumulocity.Should Have Services    name=tedge-container-monitor    service_type=service    status=up

Sends measurements
    ${date_from}=    Get Test Start Time
    Cumulocity.Device Should Have Measurements    minimum=1    after=${date_from}    timeout=90
