#!/usr/bin/env roundup

# `describe` the plan meaningfully.
describe "roundup cleanup trace"

init () {
	true
}

# This `cleanup` function is run after it_works. The `false` will simulate
# an error. Hence, `it_works` and `it_fails` should be called.
# It should be marked as failed and the `cleanup` trace should be displayed.
cleanup () {
	false
}

before() {
	true
}

after() {
	true
}

it_works () {
	true
}

it_fails () {
	false
}
