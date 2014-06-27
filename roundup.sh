#!/bin/bash
# [r5]: roundup.5.html
# [r1t]: roundup-1-test.sh.html
# [r5t]: roundup-5-test.sh.html
#
# _(c) 2010 Blake Mizerany - MIT License_
#
# Spray **roundup** on your shells to eliminate weeds and bugs.  If your shells
# survive **roundup**'s deathly toxic properties, they are considered
# roundup-ready.
#
# **roundup** reads shell scripts to form test plans.  Each
# test plan is sourced into a sandbox where each test is executed.
#
# See [roundup-1-test.sh.html][r1t] or [roundup-5-test.sh.html][r5t] for example
# test plans.
#
# __Install__
#
#     git clone http://github.com/bmizerany/roundup.git
#     cd roundup
#     make
#     sudo make install
#     # Alternatively, copy `roundup` wherever you like.
#
# __NOTE__:  Because test plans are sourced into roundup, roundup prefixes its
# variable and function names with `roundup_` to avoid name collisions.  See
# "Sandbox Test Runs" below for more insight.

# Usage and Prerequisites
# -----------------------

# Exit if any following command exits with a non-zero status.
set -e

# The current version is set during `make version`.  Do not modify this line in
# anyway unless you know what you're doing.
ROUNDUP_VERSION="0.0.5"
export ROUNDUP_VERSION

GREP='/usr/bin/grep'
TRUNCATE='/usr/bin/truncate'

# Usage is defined in a specific comment syntax. It is `$GREP`ed out of this file
# when needed (i.e. The Tomayko Method).  See
# [shocco](http://rtomayko.heroku.com/shocco) for more detail.
#/ usage: roundup [--help|-h] [--version|-v] [--debug|-d] [--test TESTCASE] [plan ...]

roundup_usage() {
    $GREP '^#/' <"$0" | cut -c4-
}

while test "$#" -gt 0
do
    case "$1" in
        --help|-h)
            roundup_usage
            exit 0
            ;;
        --version|-v)
            echo "roundup version $ROUNDUP_VERSION"
            exit 0
            ;;
        --color)
            color=always
            shift
            ;;
        --test)
            roundup_testcase=$2
            shift 2
            ;;
        --debug|-d)
            debug=1
            shift
            ;;
        -)
            echo >&2 "roundup: unknown switch $1"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Consider all scripts with names matching `*-test.sh` the plans to run unless
# otherwise specified as arguments.
if [ "$#" -gt "0" ]
then
    roundup_plans="$@"
else
    roundup_plans="$(ls *-test.sh)"
fi

: ${color:="auto"}

# Create a temporary storage place for test output to be retrieved for display
# after failing tests.
roundup_tmp=$(mktemp -d -t .roundup.XXX)
trap "rm -rf \"$roundup_tmp\"" EXIT INT

# __Tracing failures__
roundup_trace() {
    # Delete the last line which is the "set +x" of the error trap
    sed '$d'                                   |
    # Replace the rc=$? of the error trap with an verbose string appended
    # to the failing command trace line.
    sed '$s/.*rc=/exit code /'                 |
    # Indent the output by 4 spaces to align under the test name in the
    # summary.
    sed 's/^/    /'                            |
    # Highlight the last line in front of the exit code to bring notice to
    # where the error occurred.
    #
    # The sed magic puts every line into the hold buffer first, then
    # substitutes in the previous hold buffer content, prints that and starts
    # with the next cycle. At the end the last line (in the hold buffer)
    # is printed without substitution.
    sed -n "x;1!{ \$s/\(.*\)/$mag\1$clr/; };1!p;\$x;\$p"
}

# __Other helpers__

# Track the test stats while outputting a real-time report.  This takes input on
# **stdin**.  Each input line must come in the format of:
#
#     # The plan description to be displayed
#     d <plan description>
#
#     # A passing test
#     p <test name>
#
#     # A failed test
#     f <test name>
roundup_summarize() {
    set -e

    # __Colors for output__

    # Use colors if we are writing to a tty device.
    if (test -t 1) || (test $color = always)
    then
        red=$(printf "\033[31m")
        grn=$(printf "\033[32m")
        mag=$(printf "\033[35m")
        ylw=$(printf "\033[33m")
        clr=$(printf "\033[m")
        cols=$(tput cols)
    fi

    # Make these available to `roundup_trace`.
    export red grn mag clr ylw

    ntests=0
    passed=0
    skipped=0
    failed=0

    : ${cols:=10}

    prev_status=""
    while read status name
    do
        case $status in
        p|s|f)
            if [ "$debug" == 1 ]; then
                if [ "$prev_status" == l -a "$status" == f ]; then
	            rc=$(sed 's/^.*rc=//' <<<"$second_last_trace_line")
                    printf "\r    \`------------------------- exit code %-3s ---> %s " "$rc"
                elif [ "$prev_status" == l -a "$status" == s ]; then
                    printf "\r    \`-------------------------------------------> %s " ""
	        else
                    printf "\n    \`-------------------------------------------> %s " ""
                fi
            fi
            ;;
        esac
        case $status in
        p)
            ntests=$(expr $ntests + 1)
            passed=$(expr $passed + 1)
            printf "$grn[PASS]$clr\n"
            ;;
        s)
            ntests=$(expr $ntests + 1)
            skipped=$(expr $skipped + 1)
            printf "$ylw[SKIP]$clr\n"
            ;;
        f)
            ntests=$(expr $ntests + 1)
            failed=$(expr $failed + 1)
            printf "$red[FAIL]$clr\n"
            if [ "$debug" != 1 ]; then
                roundup_trace < "$roundup_tmp/$name"
            fi
            ;;
        t)
            printf "  %-48s " "$name:"
            ;;
        l)
            printf "\n    %s" "$name"
	    second_last_trace_line="$last_trace_line"
	    last_trace_line="$name"
            ;;
        d)
            printf "%s\n" "$name"
            ;;
        esac
        prev_status="$status"
    done
    # __Test Summary__
    #
    # Display the summary now that all tests are finished.
    yes = | head -n 57 | tr -d '\n'
    printf "\n"
    printf "Tests:   %3d | " $ntests
    printf "Passed:  %3d | " $passed
    printf "Skipped: %3d | " $skipped
    printf "Failed:  %3d"    $failed
    printf "\n"

    # Exit with an error if any tests failed
    test $failed -eq 0 || exit 2
}

run_with_tracing()
{
    exec 4>&1
    {
        {
            # Set `-xe` before the test in the subshell.  We want the
            # test to fail fast to allow for more accurate output of
            # where things went wrong but not in _our_ process because a
            # failed test should not immediately fail roundup.  Each
            # tests trace output is saved in temporary storage.
            set -xe
            "$1"
        } 1>&4 2>&4
        local rc=$?
        set +x
    } &>/dev/null
    exec 4>&-
    return $rc
}

start_error_handling ()
{
    # exit subshell with return code of last failing command. This
    # is needed to see the return code 253 on failed assumptions.
    # But, only do this if the error handling is activated.
    set -E
    trap 'rc=$?; set +x; set -o | $GREP "errexit.*on" >/dev/null && exit $rc' ERR
}

print_result ()
{
    if [ "$2" == 0 ]
    then printf "p"; eval export passed_$1=1
    elif [ "$2" == 253 ]
    then printf "s"
    else printf "f"
    fi

    printf " $1\n"
}

run()
{
    local func="$1"

    # show title
    if [ "$debug" == 1 ]; then
        printf "t $func\n"
    fi

    # Any number of things are possible in `$func`.
    # Drop into an subshell to contain operations that may throw
    # off `$func`; such as `cd`.
    # Momentarily turn off auto-fail to give us access to the exit status
    # in `$?` for capturing.
    set +e
    (
        start_error_handling
        run_with_tracing "$func"
    ) | $tee "$roundup_tmp/$func" | $sed 's/^/l /' >$trace_device
    roundup_result=${PIPESTATUS[0]}
    set -e

    # Check if `$func` was successful, otherwise emit fail signal
    if [ "$roundup_result" != 0 -o "$debug" == 1 ]; then
        if [ "$debug" != 1 ]; then
             printf "t $func\n"
        fi
        print_result "$func" "$roundup_result"
        if [ "$roundup_result" != 0 ]; then
             continue
        fi
    fi
}

# in debug mode, print out the traces. Otherwise,
# traces go to /dev/null
if [ "$debug" == 1 ]; then
    trace_device=/dev/stdout
else
    trace_device=/dev/null
fi
tee=$(which tee)
sed=$(which sed)

# Sandbox Test Runs
# -----------------

# The above checks guarantee we have at least one test.  We can now move through
# each specified test plan, determine its test plan, and administer each test
# listed in a isolated sandbox.
for roundup_p in $roundup_plans
do
    # Create a sandbox, source the test plan, run the tests, then leave
    # without a trace.
    (
        # Consider the description to be the `basename` of the plan minus the
        # tailing -test.sh.
        roundup_desc=$(basename "$roundup_p" -test.sh)

        # Define functions for
        # [roundup(5)][r5]

        # A custom description is recommended, but optional.  Use `describe` to
        # set the description to something more meaningful.
        # TODO: reimplement this.
        describe() {
            roundup_desc="$*"
        }

        # Helper to express an assumption for a given testcase. Example:
        # it_runs_fine() {
        #   assume it_builds_fine
        #   assume test -f foo
        #   ./binary
        # }
        assume() {
            if (echo "$1" | $GREP "^it_.*" >/dev/null)
            then if [ "$(eval echo \${passed_$1})" == 1 ]
                 then return 0
                 else return 253
                 fi
            else if eval "$@"
                 then return 0
                 else return 253
                 fi
            fi
        }

        # Provide default `before` and `after` functions that run only `:`, a
        # no-op. They may or may not be redefined by the test plan.
        init() { :; }
        before() { :; }
        after() { :; }
        cleanup() { :; }

        # Seek test methods and aggregate their names, forming a test plan.
        # This is done before populating the sandbox with tests to avoid odd
        # conflicts.

        # TODO:  I want to do this with sed only.  Please send a patch if you
        # know a cleaner way.
        if [ -n "$roundup_testcase" ]; then
            roundup_plan="$roundup_testcase"
        else
            roundup_plan=$(
                $GREP "^it_.*()" $roundup_p           |
                sed "s/\(it_[a-zA-Z0-9_]*\).*$/\1/g"
            )
        fi

        # We have the test plan and are in our sandbox with [roundup(5)][r5]
        # defined.  Now we source the plan to bring its tests into scope.
        . ./$roundup_p

        # Output the description signal
        printf "d %s\n" "$roundup_desc" | tr "\n" " "
        printf "\n"

        # Run `init` function of the current plan. THis will be done before any of
        # the tests in the plan are executed.
        # If `init` wasn't redefined, then this is `:`.
        run "init"

        for roundup_test_name in $roundup_plan
        do
            echo "t $roundup_test_name"

            # Any number of things are possible in `before`, `after`, and the
            # test.  Drop into an subshell to contain operations that may throw
            # off roundup; such as `cd`.
            # Momentarily turn off auto-fail to give us access to the tests
            # exit status in `$?` for capturing.
            set +e
            (
                # start bash error handling
                start_error_handling

                # run after method in any case
                trap 'rc=$?; set +x; if [ "$rc" == 0 ]; then run_with_tracing after; else set +xe; after; exit $rc; fi' EXIT

                # If `before` wasn't redefined, then this is `:`.
                run_with_tracing before

                # Define a helper to log stdout to the file stdout and stderr to the
                # file stderr. This can be used like this:
                #   capture ls asdf
                #   $GREP "error" stderr
                capture () {
                    # resetting the output buffers before capturing. This should
                    # guarantee that old data has been erases when running
                    # capture multiple times during a test
                    $TRUNCATE -s 0 $roundup_tmp/{stdout,stderr,rc}
                    {
                         "$@" 2>&1 1>&3 | tee -- $roundup_tmp/stderr | awk "{ print \"\033[31m\"\$0\"\033[m\"; }" 1>&2
                         return ${PIPESTATUS[0]};
                    } 3>&1 | tee -- $roundup_tmp/stdout
                    ret=${PIPESTATUS[0]}
                    echo "$ret" > $roundup_tmp/rc
                    return $ret
                }

                # defining helper functions and resetting the output buffers
                # before running the next test
                stdout () { echo -n "$roundup_tmp/stdout"; }
                stderr () { echo -n "$roundup_tmp/stderr"; }
                rc ()     { echo -n "$roundup_tmp/rc"; }
                echo "debug $roundup_tmp/{stdout,stderr,rc}"
                $TRUNCATE -s 0 $roundup_tmp/{stdout,stderr,rc}

                # Define a negating operator which triggers the error trap of the shell. The
                # builtin ! will not.
                function expectfail () { ! "$@"; }

                # run test
                run_with_tracing "$roundup_test_name"
            ) | $tee "$roundup_tmp/$roundup_test_name" | $sed 's/^/l /' >$trace_device

            # copy roundup_result from subshell above
            roundup_result=${PIPESTATUS[0]}

            # It's safe to return to normal operation.
            set -e

            # This is the final step of a test.  Print its pass/fail signal
            # and name.
            print_result "$roundup_test_name" "$roundup_result"
        done

        # Run `cleanup` function of the current plan.
        # This function is guaranteed to run after the last test case.
        # If `cleanup` wasn't redefined, then this is `:`.
        run "cleanup"
    )
done |

# All signals are piped to this for summary.
roundup_summarize
