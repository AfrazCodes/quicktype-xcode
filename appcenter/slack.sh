ORG=quicktype
APP=quiktype-xcode

ICON=https://pbs.twimg.com/profile_images/881784177422725121/hXRP69QY_200x200.jpg

build_url=https://appcenter.ms/orgs/$ORG/apps/$APP/build/branches/$APPCENTER_BRANCH/builds/$APPCENTER_BUILD_ID
build_link="<$build_url|$APP $APPCENTER_BRANCH#$APPCENTER_BUILD_ID>"

TESTER_URL="https://install.appcenter.ms/orgs/quicktype/apps/quicktype-xcode/distribution_groups/xcode%20testers"

slack_notify() {
    local message
    local "${@}"

    curl -X POST --data-urlencode \
        "payload={
            \"channel\": \"#notifications\",
            \"username\": \"App Center\",
            \"text\": \"$message\",
            \"icon_url\": \"$ICON\" \
        }" \
        $SLACK_WEBHOOK
}

slack_notify_build_passed() {
    slack_notify message="✓ Build $build_link passed"
}

slack_notify_build_failed() {
    slack_notify message="💥 Build $build_link failed"
}

slack_notify_deployed() {
    slack_notify message="✓ <$TESTER_URL|$APP ($APPCENTER_BRANCH)> distributed to testers"
}