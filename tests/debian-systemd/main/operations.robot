*** Settings ***
Resource    ../../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Set Main Device

*** Test Cases ***

Restart device
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${operation}=    Cumulocity.Restart Device
    Cumulocity.Device Should Have Event/s    expected_text=.*Warning: device is about to reboot.*    minimum=1    maximum=1    type=device_reboot    after=${date_from}
    Operation Should Be SUCCESSFUL    ${operation}    timeout=120
    Cumulocity.Device Should Have Event/s    expected_text=tedge started up.+    minimum=1    maximum=1    type=startup    after=${date_from}

Install software package
    ${operation}=    Cumulocity.Install Software    vim-tiny,latest::apt
    Operation Should Be SUCCESSFUL    ${operation}    timeout=90
    Cumulocity.Device Should Have Installed Software    vim-tiny

Uninstall software package
    ${operation}=    Cumulocity.Uninstall Software    vim-tiny    timeout=90
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

*** Keywords ***

Get Logfile Request
    [Arguments]    ${name}
    ${operation}=    Cumulocity.Create Operation    description=Get Log File    fragments={"c8y_LogfileRequest": {"dateFrom": "2023-05-08T20:46:56+0200","dateTo": "2023-05-09T20:46:56+0200","logFile": "${name}","maximumLines": 1000,"searchText": ""}}
    ${operation}=    Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_LogfileRequest"]["file"]}
