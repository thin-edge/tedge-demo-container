*** Settings ***
Resource    ../resources/common.robot
Library    Cumulocity
Library    DeviceLibrary

Suite Setup    Suite Setup

*** Test Cases ***

Get Configuration
    ${operation}=    Cumulocity.Get Configuration    typename=tedge-container-plugin
    Operation Should Be SUCCESSFUL    ${operation}

Install container-group package
    ${binary_url}=    Cumulocity.Create Inventory Binary    nginx    container-group    file=${CURDIR}/data/docker-compose.nginx.yaml
    ${operation}=    Cumulocity.Install Software    {"name": "nginx", "version": "1.0.0", "softwareType": "container-group", "url": "${binary_url}"}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Have Installed Software    {"name": "nginx", "version": "1.0.0", "softwareType": "container-group"}
    ${operation}=    Cumulocity.Execute Shell Command    wget -O- nginx:80
    Operation Should Be SUCCESSFUL    ${operation}
    Should Contain    ${operation.to_json()["c8y_Command"]["result"]}    Welcome to nginx

Uninstall container-group
    ${operation}=     Cumulocity.Uninstall Software    {"name": "nginx", "version": "1.0.0", "softwareType": "container-group"}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Not Have Installed Software    nginx

Install container package
    ${operation}=    Cumulocity.Install Software    {"name": "webserver", "version": "httpd:2.4", "softwareType": "container"}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Have Installed Software    {"name": "webserver", "version": "httpd:2.4", "softwareType": "container"}
    ${operation}=    Cumulocity.Execute Shell Command    wget -O- webserver:80
    Operation Should Be SUCCESSFUL    ${operation}
    Should Contain    ${operation.to_json()["c8y_Command"]["result"]}    It works!

Uninstall container package
    ${operation}=     Cumulocity.Uninstall Software    {"name": "webserver", "version": "httpd:2.4", "softwareType": "container"}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Not Have Installed Software    webserver


*** Keywords ***

Suite Setup
    Set Main Device
