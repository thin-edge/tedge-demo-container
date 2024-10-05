*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

Service status
    Cumulocity.Should Have Services    name=tedge-agent    service_type=service    status=up

Sends measurements
    Skip    Container does not publish measurements by default
    ${date_from}=    Get Test Start Time
    Cumulocity.Device Should Have Measurements    minimum=2    after=${date_from}    timeout=30

Agent information
    ${mo}=    Cumulocity.Device Should Have Fragments    c8y_Agent
    Log    ${mo["c8y_Agent"]}
    Should Not Be Empty    ${mo["c8y_Agent"]["name"]}
    Should Not Be Empty    ${mo["c8y_Agent"]["version"]}
    Should Not Be Empty    ${mo["c8y_Agent"]["url"]}
