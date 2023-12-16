*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device1

*** Test Cases ***

It Should Show Supported Log File Types
    Cumulocity.Should Have Services    name=tedge-agent    status=up
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

Restart Device
    ${operation}=    Cumulocity.Restart Device
    Operation Should Be SUCCESSFUL    ${operation}

It Should List the Installed Software
    Device Should Have Installed Software    ca-certificates    tedge-apk-plugin
    # Device Should Have Installed Software    tedge    tedge-agent

Install software (apk package)
    Skip    msg=TODO
    ${operation}=    Install Software    jq,latest::apk
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Have Installed Software    jq

Uninstall software (apk package)
    Skip    msg=TODO
    ${operation}=     Uninstall Software    jq,latest::apk
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Not Have Installed Software    jq

*** Keywords ***

Revert Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    tedge-configuration-plugin-1.toml    tedge-configuration-plugin    file=${CURDIR}/tedge-configuration-plugin-1.toml
    ${operation}=    Cumulocity.Set Configuration    typename=tedge-configuration-plugin    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
