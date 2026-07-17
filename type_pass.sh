#!/system/bin/sh
# Password field
input tap 640 1613
sleep 0.3
input text Test@2026!
sleep 0.3

# Confirm password field
input tap 640 1815
sleep 0.3
input text Test@2026!
sleep 0.3

echo DONE