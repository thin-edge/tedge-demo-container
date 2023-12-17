*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Main Device

*** Test Cases ***

Service status
    Cumulocity.Should Have Services    name=tedge-mapper-c8y             service_type=service    status=up    timeout=90
    Cumulocity.Should Have Services    name=tedge-agent                  service_type=service    status=up
    Cumulocity.Should Have Services    name=mosquitto-c8y-bridge         service_type=service    status=up
    Cumulocity.Should Have Services    name=tedge-container-monitor      service_type=service    status=up

Sends measurements
    ${date_from}=    Get Test Start Time
    Cumulocity.Execute Shell Command    tedge mqtt pub te/device/main///m/environment '{"temp":1.234}'
    Cumulocity.Device Should Have Measurements    minimum=1    maximum=1    type=environment    after=${date_from}
