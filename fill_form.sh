#!/system/bin/sh
# Fill registration form fields
# Field coordinates from UIAutomator dump

# Full Name field - tap and type
input tap 640 1208
sleep 0.5
input text E2E
input keyevent 62
input text Test
sleep 0.5

# Email field - tap and type
input tap 640 1411
sleep 0.5
input text e2etest
input text 20260717
input keyevent 77
input text gmail.com
sleep 0.5

# Password field - tap and type
input tap 640 1613
sleep 0.5
input text Test
input keyevent 77
input text 2026!
sleep 0.5

# Confirm Password field - tap and type
input tap 640 1815
sleep 0.5
input text Test
input keyevent 77
input text 2026!
sleep 0.5

echo DONE