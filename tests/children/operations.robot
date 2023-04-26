*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

Install Firmware
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${binary_url}=    Cumulocity.Create Inventory Binary    iot-linux    child-firmware    contents=dummy_file
    ${operation}=    Cumulocity.Install Firmware    name=iot-linux    version=1.0.0    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
    Cumulocity.Device Should Have Fragment Values    c8y_Firmware.name\=iot-linux    c8y_Firmware.version\=1.0.0    c8y_Firmware.url\=${binary_url}
    Cumulocity.Device Should Have Event/s    expected_text=Applying firmware: iot-linux=1.0.0    minimum=1    maximum=1    type=firmware_update_start    after=${date_from}
    Cumulocity.Device Should Have Event/s    expected_text=Finished applying firmware: iot-linux=1.0.0, duration=0:00:10    minimum=1    maximum=1    type=firmware_update_done    after=${date_from}

Set Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    modem_v2    child-modem-config    contents={"version":"2"}
    ${operation}=    Cumulocity.Set Configuration    typename=modem    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}

Get Configuration
    ${operation}=    Cumulocity.Get Configuration    typename=modem
    Operation Should Be SUCCESSFUL    ${operation}
