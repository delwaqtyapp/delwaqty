#!/system/bin/sh
# Skip onboarding
sleep 2
input tap 1137 236
sleep 3
# On welcome page, tap "I already have an account"
input tap 640 2288
sleep 3
echo NAV_DONE