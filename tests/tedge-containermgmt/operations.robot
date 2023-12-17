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
    ${operation}=    Cumulocity.Install Software    nginx,1.0.0::container-group,${binary_url}
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Have Installed Software    nginx,1.0.0
    ${operation}=    Cumulocity.Execute Shell Command    wget -O- nginx:80
    Operation Should Be SUCCESSFUL    ${operation}
    Should Contain    ${operation.to_json()["c8y_Command"]["result"]}    Welcome to nginx

Uninstall container-group
    ${operation}=     Cumulocity.Uninstall Software    nginx,1.0.0::container-group
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Not Have Installed Software    nginx

Install container package
    ${operation}=    Cumulocity.Install Software    webserver,httpd:2.4::container
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Have Installed Software    webserver,httpd:2.4
    ${operation}=    Cumulocity.Execute Shell Command    wget -O- webserver:80
    Operation Should Be SUCCESSFUL    ${operation}
    Should Contain    ${operation.to_json()["c8y_Command"]["result"]}    It works!

Uninstall container package
    ${operation}=     Cumulocity.Uninstall Software    webserver,httpd:2.4::container
    Operation Should Be SUCCESSFUL    ${operation}
    Device Should Not Have Installed Software    webserver


*** Keywords ***

Suite Setup
    Set Main Device
