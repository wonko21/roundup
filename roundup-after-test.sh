#!/usr/bin/env roundup

# `describe` the plan meaningfully.
describe "roundup after trace"

# This `after` function is run after it_works. The `false` will simulate
# an error. Hence, `it_works` and `it_fails` should be called.
# It should be marked as failed and the `after` trace should be displayed.
after() {
	false
}

it_fails () {
	false
}

it_works () {
	true
}
