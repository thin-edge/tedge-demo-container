*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device2

*** Test Cases ***

Install Firmware
    Cumulocity.Should Have Services    name=tedge-agent    status=up
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${binary_url}=    Cumulocity.Create Inventory Binary    iot-linux    child-firmware    contents=dummy_file
    ${operation}=    Cumulocity.Install Firmware    name=iot-linux    version=1.0.0    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}    timeout=90
    Cumulocity.Device Should Have Fragment Values    c8y_Firmware.name\=iot-linux    c8y_Firmware.version\=1.0.0    c8y_Firmware.url\=${binary_url}

Set Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    modem_v2    child-modem-config    contents={"version":"2"}
    ${operation}=    Cumulocity.Set Configuration    typename=modem    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}

Get Configuration
    ${operation}=    Cumulocity.Get Configuration    typename=modem
    Operation Should Be SUCCESSFUL    ${operation}
