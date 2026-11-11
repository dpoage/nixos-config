---
description: Never re-pin a test's expected values to match whatever the code now outputs
scope: "tool:edit(*{test,spec}*), tool:write(*{test,spec}*), tool:edit(**/{test,tests,spec,__tests__}/**), tool:write(**/{test,tests,spec,__tests__}/**)"
question: "The content is an edit to a test file. Answer yes if the edit changes expected values (the expected side of an assertion, a snapshot, golden data, an expected count, string, or error) while leaving the test's setup, inputs, and the call under test unchanged, so that the test now matches what the code currently outputs. Answer no if the edit adds new tests, changes inputs or setup together with the expectations, or deletes a test."
---
Your edit re-pinned a test's expectations to the code's current output. Decide which case holds:

- The old expectation pinned real behavior: the code regressed. Revert the test edit and fix the code.
- It pinned wording or incidental behavior: delete the assertion or the test.
- The user changed the contract: keep the edit and name that change in your report.
