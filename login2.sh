#!/system/bin/sh
# Tap email field
input tap 663 1833
sleep 0.5
# Type full email - @ works on device shell
input text said.3pkarino@gmail.com
sleep 0.5
# Tab to password
input keyevent 61
sleep 0.5
# Type password
input text Ed@20266
sleep 0.5
# Dismiss keyboard
input keyevent 4
sleep 1
echo TYPED