*** Settings ***
Resource    ../../resources/common.robot
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
    # TODO: Enable once the tedge-container-monitor service has been released
    # Cumulocity.Should Have Services    name=tedge-container-monitor    service_type=service    status=up

Sends measurements
    ${date_from}=    Get Test Start Time
    Cumulocity.Device Should Have Measurements    minimum=1    after=${date_from}    timeout=120

Inventory Script: OS information
    ${mo}=    Cumulocity.Device Should Have Fragments    device_OS
    Log    ${mo["device_OS"]}
    Should Not Be Empty    ${mo["device_OS"]["arch"]}
    Should Not Be Empty    ${mo["device_OS"]["displayName"]}
    Should Not Be Empty    ${mo["device_OS"]["family"]}
    Should Not Be Empty    ${mo["device_OS"]["hostname"]}
    Should Not Be Empty    ${mo["device_OS"]["kernel"]}
    Should Not Be Empty    ${mo["device_OS"]["version"]}

Inventory Script: Hardware information
    ${mo}=    Cumulocity.Device Should Have Fragments    c8y_Hardware
    Log    ${mo["c8y_Hardware"]}
    Should Not Be Empty    ${mo["c8y_Hardware"]["model"]}
    Should Not Be Empty    ${mo["c8y_Hardware"]["serialNumber"]}
    Should Not Be Empty    ${mo["c8y_Hardware"]["revision"]}
