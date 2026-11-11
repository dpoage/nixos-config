---
description: Never re-pin a test's expected values to match whatever the code now outputs
scope: "tool:edit(*_test.go), tool:write(*_test.go), tool:edit(*.{test,spec}.{ts,tsx,js,jsx,mts,cts,mjs,cjs}), tool:write(*.{test,spec}.{ts,tsx,js,jsx,mts,cts,mjs,cjs}), tool:edit(test_*.py), tool:write(test_*.py), tool:edit(*_test.py), tool:write(*_test.py), tool:edit(*_spec.rb), tool:write(*_spec.rb), tool:edit(*.{snap,golden}), tool:write(*.{snap,golden}), tool:edit(**/{test,tests,spec,__tests__,__snapshots__,testdata}/**), tool:write(**/{test,tests,spec,__tests__,__snapshots__,testdata}/**), tool:edit(*.rs)"
question: "The content is the lines an edit adds to a test file, snapshot, golden file, or Rust source file (which may hold inline tests); removed and unchanged lines are not shown. Answer yes if the added lines change only expected values (the expected side of an assertion, a snapshot, golden data, an expected count, string, or error) and add no setup, input, or call under test, so the test now matches what the code currently outputs. Answer no if the added lines are not test code, add a new test, change inputs or setup together with the expectations, or the edit only deletes a test."
---
Your edit re-pinned a test's expectations to the code's current output. Decide which case holds:

- The old expectation pinned real behavior: the code regressed. Revert the test edit and fix the code.
- It pinned wording or incidental behavior: delete the assertion or the test.
- The user changed the contract: keep the edit and name that change in your report.
