[![Build Status](https://travis-ci.org/wonko21/roundup.svg?branch=master)](https://travis-ci.org/wonko21/roundup)

roundup - kills shell eating bugs and weeds

roundup(1) is a unit testing tool for running roundup(5) test plans which are
written in any POSIX shell.  Each test in a plan is run in it's own isolated
sandbox.  A test can pass, be ignored, or fail.  Failed tests output their `set
-x` trace.

This Version is branched of off http://bmizerany.github.com/roundup since development there
has stalled. We use roundup exensively and plan to maintain and extend it at https://github.com/dfs-sh/roundup

Improvements include:
 * Stability in Test detection
 * Support for library use
 * Export of result in JUnit XML  

Original information and examples:
  http://itsbonus.heroku.com/p/2010-11-01-roundup
  http://bmizerany.github.com/roundup
