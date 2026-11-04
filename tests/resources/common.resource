*** Settings ***
Library    Cumulocity
Library    DeviceLibrary

*** Variables ***

${DEVICE_ID}
${CHILD_DEVICE_1}
${CHILD_DEVICE_2}
${IMAGE}    %{IMAGE=debian-systemd}

# Cumulocity settings
&{C8Y_CONFIG}        host=%{C8Y_BASEURL= }    username=%{C8Y_USER= }    password=%{C8Y_PASSWORD= }    tenant=%{C8Y_TENANT= }

*** Keywords ***

Set Main Device
    Cumulocity.Set Device    ${DEVICE_ID}
    DeviceLibrary.Set Device Context    main

Set Child Device1
    Cumulocity.Set Device    ${CHILD_DEVICE_1}
    DeviceLibrary.Set Device Context    ${DEVICE_ID}:child01

Set Child Device2
    Cumulocity.Set Device    ${CHILD_DEVICE_2}
    DeviceLibrary.Set Device Context    ${DEVICE_ID}:child02

Setup Device
    ${DEVICE_ID}=    DeviceLibrary.Setup    compose_file=${CURDIR}/../../images/${IMAGE}/docker-compose.yaml    skip_bootstrap=${True}
    Set Suite Variable    $DEVICE_ID
    Bootstrap Device    ${DEVICE_ID}

Bootstrap Device
    [Arguments]    ${device_id}
    ${domain}=    Cumulocity.Get Domain
    DeviceLibrary.Execute Command    cmd=tedge config set c8y.url ${domain}
    ${credentials}=    Cumulocity.Bulk Register Device With Cumulocity CA    external_id=${device_id}
    DeviceLibrary.Execute Command    cmd=tedge config set c8y.proxy.client.host tedge
    DeviceLibrary.Execute Command    cmd=tedge config set c8y.proxy.bind.address 0.0.0.0
    DeviceLibrary.Execute Command    cmd=tedge cert download c8y --device-id ${device_id} --retry-every 5s --one-time-password '${credentials.one_time_password}' --max-timeout 60s
    DeviceLibrary.Execute Command    cmd=tedge reconnect c8y
    Cumulocity.External Identity Should Exist    external_id=${device_id}
    ${operation}=    Cumulocity.Get Configuration    typename=tedge-configuration-plugin    timeout=60
    Cumulocity.Operation Should Be SUCCESSFUL    ${operation}
    Set Suite Variable    ${CHILD_DEVICE_1}    ${device_id}:device:child01
    Set Suite Variable    ${CHILD_DEVICE_2}    ${device_id}:device:child02
    Sleep    2s

Collect Logs
    [Arguments]    ${name}=
    IF    "${name}"!="${EMPTY}"
        DeviceLibrary.Set Device Context    ${name}
    END
    
    Run Keyword And Continue On Failure    Get Workflow Logs
    Run Keyword And Continue On Failure    Get Service Logs

Get Workflow Logs
    DeviceLibrary.Execute Command    cmd=test -e /var/log/tedge/agent && head -n-0 /var/log/tedge/agent/*    ignore_exit_code=${True}

Get Service Logs
    DeviceLibrary.Execute Command    cmd=command -V journalctl >/dev/null 2>&1 && journalctl -n 1000 --no-pager -u "tedge-*"    ignore_exit_code=${True}
