*** Settings ***
Library    Cumulocity

*** Variables ***

${DEVICE_ID}         %{DEVICE_ID=main}
${CHILD_DEVICE_1}    ${DEVICE_ID}:device:child01
${CHILD_DEVICE_2}    ${DEVICE_ID}:device:child02
${CHILD_DEVICE_3}    ${DEVICE_ID}:device:child03

# Cumulocity settings
&{C8Y_CONFIG}        host=%{C8Y_BASEURL= }    username=%{C8Y_USER= }    password=%{C8Y_PASSWORD= }    tenant=%{C8Y_TENANT= }

*** Keywords ***

Set Main Device
    Cumulocity.Set Device    ${DEVICE_ID}

Set Child Device1
    Cumulocity.Set Device    ${CHILD_DEVICE_1}

Set Child Device2
    Cumulocity.Set Device    ${CHILD_DEVICE_2}

Set Child Device3
    Cumulocity.Set Device    ${CHILD_DEVICE_3}
