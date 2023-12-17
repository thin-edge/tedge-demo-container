*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

Service status
    Cumulocity.Should Have Services    name=tedge-agent    service_type=service    status=up
