*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

It Should Show Supported Log File Types
    Cumulocity.Should Have Services    name=tedge-log-plugin    status=up
    Cumulocity.Should Support Log File Types    software-management    shell

Get Log File
    ${operation}=     Cumulocity.Get Log File    type=software-management
    Operation Should Be SUCCESSFUL    ${operation}

Set Configuration
    [Teardown]    Revert Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    tedge-configuration-plugin-2.toml    tedge-configuration-plugin    file=${CURDIR}/tedge-configuration-plugin-2.toml
    ${operation}=    Cumulocity.Set Configuration    typename=tedge-configuration-plugin    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
    Cumulocity.Should Support Configurations    tedge-configuration-plugin    tedge.toml    system.toml    tedge-log-plugin.toml

Get Configuration
    ${operation}=    Cumulocity.Get Configuration    typename=tedge-configuration-plugin
    Operation Should Be SUCCESSFUL    ${operation}

*** Keywords ***

Revert Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    tedge-configuration-plugin-1.toml    tedge-configuration-plugin    file=${CURDIR}/tedge-configuration-plugin-1.toml
    ${operation}=    Cumulocity.Set Configuration    typename=tedge-configuration-plugin    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
