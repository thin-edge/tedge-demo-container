*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary


*** Test Cases ***

It Should Show Supported Log File Types
    [Template]    Check Supported Log File Types
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Get Log File
    [Template]    Get Log File
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Set Configuration
    [Template]    Set Configuration
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Get Configuration
    [Template]    Get Configuration
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Restart Device
    [Template]    Restart Device
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

It Should List the Installed Software
    [Template]    Check Software List
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Install software (apk package)
    [Template]    Install software
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Uninstall software (apk package)
    [Template]    Uninstall software
    ${DEVICE_ID}
    ${CHILD_DEVICE_1}

Execute shell command
    [Template]    Execute shell command
    ${DEVICE_ID}

Get Logfile Request
    [Template]    Get Logfile Request
    ${DEVICE_ID}         software-management
    ${CHILD_DEVICE_1}    software-management

*** Keywords ***

Check Supported Log File Types
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    Cumulocity.Should Have Services    name=tedge-agent    status=up
    Cumulocity.Should Support Log File Types    software-management    shell

Get Log File
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    ${operation}=     Cumulocity.Get Log File    type=software-management
    Operation Should Be SUCCESSFUL    ${operation}

Set Configuration
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    [Teardown]    Revert Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    tedge-configuration-plugin-2.toml    tedge-configuration-plugin    file=${CURDIR}/data/tedge-configuration-plugin-2.toml
    ${operation}=    Cumulocity.Set Configuration    typename=tedge-configuration-plugin    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
    Cumulocity.Should Support Configurations    tedge-configuration-plugin    tedge.toml    system.toml    tedge-log-plugin.toml

Get Configuration
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    ${operation}=    Cumulocity.Get Configuration    typename=tedge-configuration-plugin
    Operation Should Be SUCCESSFUL    ${operation}

Restart Device
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    ${operation}=    Cumulocity.Restart Device
    Operation Should Be SUCCESSFUL    ${operation}

Check Software List
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    Device Should Have Installed Software    ca-certificates    tedge-apk-plugin

Install software
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    ${operation}=    Cumulocity.Install Software    {"name": "htop", "version": "latest", "softwareType": "apk"}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Have Installed Software    htop

Uninstall software
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    ${operation}=     Cumulocity.Uninstall Software    {"name": "htop", "version": "latest", "softwareType": "apk"}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Not Have Installed Software    htop

Execute shell command
    [Arguments]    ${device}
    Cumulocity.Set Device    ${device}
    ${operation}=    Cumulocity.Execute Shell Command    ls -l /etc/tedge
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_Command"]["result"]}

Get Logfile Request
    [Arguments]    ${device}    ${name}
    Cumulocity.Set Device    ${device}
    ${operation}=    Cumulocity.Create Operation    description=Get Log File    fragments={"c8y_LogfileRequest": {"dateFrom": "2023-05-08T20:46:56+0200","dateTo": "2023-05-09T20:46:56+0200","logFile": "${name}","maximumLines": 1000,"searchText": ""}}
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_LogfileRequest"]["file"]}

Revert Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    tedge-configuration-plugin-1.toml    tedge-configuration-plugin    file=${CURDIR}/data/tedge-configuration-plugin-1.toml
    ${operation}=    Cumulocity.Set Configuration    typename=tedge-configuration-plugin    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
