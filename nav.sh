#!/system/bin/sh
sleep 2
# Dump UI to find Skip button
uiautomator dump /sdcard/nav.xml 2>/dev/null
# Tap Skip area (top right)
input tap 1137 236
sleep 2
# Tap Create a new account
input tap 640 2466
sleep 3
# Dump UI to see form
uiautomator dump /sdcard/form.xml 2>/dev/null
echo NAV_DONE