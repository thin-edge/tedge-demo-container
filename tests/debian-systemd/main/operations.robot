*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Main Device

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
    Cumulocity.Managed Object Should Have Fragment Values    c8y_Firmware.name\=iot-linux    c8y_Firmware.version\=2.0.0    c8y_Firmware.url\=${binary_url}

Restart device
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${operation}=    Cumulocity.Restart Device
    Cumulocity.Device Should Have Event/s    expected_text=.*Warning: device is about to reboot.*    minimum=1    maximum=1    type=device_reboot    after=${date_from}
    Operation Should Be SUCCESSFUL    ${operation}    timeout=120
    # FIXME: Investigate why this event can sometimes be duplicated
    Cumulocity.Device Should Have Event/s    expected_text=tedge started up.+    minimum=1    maximum=2    type=startup    after=${date_from}

Install software package
    ${operation}=    Cumulocity.Install Software    {"name": "vim-tiny", "version": "latest", "softwareType": "apt"}
    Operation Should Be SUCCESSFUL    ${operation}    timeout=90
    Cumulocity.Device Should Have Installed Software    vim-tiny

    # lib* packages should be excluded by default due to the custom tedge.toml config
    Cumulocity.Device Should Not Have Installed Software    libc-bin

Uninstall software package
    ${operation}=    Cumulocity.Uninstall Software    {"name": "vim-tiny", "softwareType": "apt"}    timeout=90
    Operation Should Be SUCCESSFUL    ${operation}
    Cumulocity.Device Should Not Have Installed Software    vim-tiny

Execute shell command
    ${operation}=    Cumulocity.Execute Shell Command    ls -l /etc/tedge
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_Command"]["result"]}

Get Logfile Request
    [Template]    Get Logfile Request
    software-management
    apt-terminal-log
    dpkg

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

*** Keywords ***

Get Logfile Request
    [Arguments]    ${name}
    ${operation}=    Cumulocity.Create Operation    description=Get Log File    fragments={"c8y_LogfileRequest": {"dateFrom": "2023-05-08T20:46:56+0200","dateTo": "2023-05-09T20:46:56+0200","logFile": "${name}","maximumLines": 1000,"searchText": ""}}
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_LogfileRequest"]["file"]}
