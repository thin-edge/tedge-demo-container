*** Settings ***
Resource    ../../resources/common.resource

Suite Setup    Setup Device
Suite Teardown    Collect Logs

*** Test Cases ***

Restart device
    ${date_from}=    Get Test Start Time
    Sleep    1s
    ${operation}=    Cumulocity.Restart Device
    # Cumulocity.Device Should Have Event/s    expected_text=.*Warning: device is about to reboot.*    minimum=1    maximum=1    type=device_reboot    after=${date_from}
    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}    timeout=120

# Get Logfile Request
#     [Template]    Get Logfile Request
#     software-management

*** Keywords ***

Get Logfile Request
    [Arguments]    ${name}
    ${operation}=    Cumulocity.Create Operation    description=Get Log File    fragments={"c8y_LogfileRequest": {"dateFrom": "2023-05-08T20:46:56+0200","dateTo": "2023-05-09T20:46:56+0200","logFile": "${name}","maximumLines": 1000,"searchText": ""}}
    ${operation}=    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}
    Should Not Be Empty    ${operation["c8y_LogfileRequest"]["file"]}
