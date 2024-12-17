*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Child Device2

*** Test Cases ***

Firmware information should be shown on startup
    Cumulocity.Managed Object Should Have Fragment Values    c8y_Firmware.name\=iot-linux    c8y_Firmware.version\=1.0.0

Install Firmware
    Cumulocity.Should Have Services    name=tedge-agent    status=up
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${binary_url}=    Cumulocity.Create Inventory Binary    iot-linux    child-firmware    contents=dummy_file
    ${operation}=    Cumulocity.Install Firmware    name=iot-linux    version=2.0.0    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}    timeout=90
    Cumulocity.Device Should Have Fragment Values    c8y_Firmware.name\=iot-linux    c8y_Firmware.version\=2.0.0    c8y_Firmware.url\=${binary_url}

Set Configuration
    ${binary_url}=    Cumulocity.Create Inventory Binary    modem_v2    child-modem-config    contents={"version":"2"}
    ${operation}=    Cumulocity.Set Configuration    typename=modem    url=${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}

Get Configuration
    ${operation}=    Cumulocity.Get Configuration    typename=modem
    Operation Should Be SUCCESSFUL    ${operation}

Install software package
    ${operation}=    Cumulocity.Install Software    {"name": "vim-tiny", "version": "latest", "softwareType": "apt"}
    Operation Should Be SUCCESSFUL    ${operation}    timeout=90
    Cumulocity.Device Should Have Installed Software    vim-tiny

    # lib* packages should be excluded by default due to the custom tedge.toml config
    Cumulocity.Device Should Not Have Installed Software    libc-bin

Install device profile
    ${config_url}=    Create Inventory Binary
    ...    tedge-configuration-plugin
    ...    tedge-configuration-plugin
    ...    file=${CURDIR}/../tedge-configuration-plugin.toml

    ${PROFILE_NAME}=    Set Variable    Test Profile
    ${PROFILE_PAYLOAD}=    Catenate    SEPARATOR=\n    {
    ...      "firmware": {
    ...        "name":"iot-linux",
    ...        "version":"3.0.0",
    ...        "url":"https://abc.com/some/firmware/url"
    ...      },
    ...      "software":[
    ...        {
    ...          "name":"jq",
    ...          "action":"install",
    ...          "version":"latest",
    ...          "url":""
    ...        }
    ...      ],
    ...      "configuration":[
    ...        {
    ...          "name":"tedge-configuration-plugin",
    ...          "type":"tedge-configuration-plugin",
    ...          "url":"${config_url}"
    ...        }
    ...      ]
    ...    }

    ${profile}=    Cumulocity.Create Device Profile    ${PROFILE_NAME}    ${PROFILE_PAYLOAD}
    ${operation}=    Cumulocity.Install Device Profile    ${profile["id"]}
    ${operation}=    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}
    Cumulocity.Should Have Device Profile Installed    ${profile["id"]}

    # Check meta information
    Cumulocity.Managed Object Should Have Fragment Values    c8y_Firmware.name\=iot-linux    c8y_Firmware.version\=3.0.0
    Cumulocity.Device Should Have Installed Software    {"name":"jq"}
    Cumulocity.Should Support Configurations    container.env    includes=${True}

Execute shell command
    ${operation}=    Cumulocity.Execute Shell Command    ls -l /etc/tedge
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_Command"]["result"]}
