*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

Service status
    Cumulocity.Should Have Services    name=connector    service_type=service    status=up

Sends measurements
    ${date_from}=    Get Test Start Time
    Cumulocity.Device Should Have Measurements    minimum=2    after=${date_from}    timeout=30
