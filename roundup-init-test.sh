#!/usr/bin/env roundup

# `describe` the plan meaningfully.
describe "roundup init trace"

# This `init` function is run before all other functions. The `false` will
# simulate an error. Hence, `before`, `it_works`, `after` and `cleanup` should
# not be called at all, but it should be  marked as failed and the `init`
# trace should be displayed.
init() {
	false
}

#
# The following functtons are never reached
#

cleanup() {
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
