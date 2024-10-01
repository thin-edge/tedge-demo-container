*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

Service status
    Skip    python child agent is disabled for now
    Cumulocity.Should Have Services    name=connector    service_type=service    status=up

Sends measurements
    Skip    python child agent is disabled for now
    ${date_from}=    Get Test Start Time
    Cumulocity.Device Should Have Measurements    minimum=2    after=${date_from}    timeout=30
