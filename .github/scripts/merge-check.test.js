const assert = require("node:assert/strict");
const test = require("node:test");

const { evaluateWorkflowRuns } = require("./merge-check.js");

function workflowRun({
  workflowId,
  runNumber,
  name,
  status = "completed",
  conclusion = "success",
}) {
  return {
    workflow_id: workflowId,
    run_number: runNumber,
    run_attempt: 1,
    name,
    status,
    conclusion,
  };
}

test("passes only after every current PR workflow succeeds", () => {
  const docs = workflowRun({
    workflowId: 1,
    runNumber: 10,
    name: "Docs",
  });
  const packageRun = {
    workflowId: 2,
    runNumber: 20,
    name: "Package CI",
  };
  const cases = [
    {
      name: "no visible workflow",
      runs: [],
      expected: "pending",
    },
    {
      name: "workflow still running",
      runs: [
        docs,
        workflowRun({
          ...packageRun,
          status: "in_progress",
          conclusion: null,
        }),
      ],
      expected: "pending",
    },
    {
      name: "workflow failed",
      runs: [docs, workflowRun({ ...packageRun, conclusion: "failure" })],
      expected: "failure",
    },
    {
      name: "all workflows succeeded",
      runs: [docs, workflowRun(packageRun)],
      expected: "success",
    },
    {
      name: "latest run supersedes an earlier failure",
      runs: [
        docs,
        workflowRun({
          ...packageRun,
          runNumber: 19,
          conclusion: "failure",
        }),
        workflowRun(packageRun),
      ],
      expected: "success",
    },
  ];

  for (const testCase of cases) {
    assert.equal(
      evaluateWorkflowRuns(testCase.runs).state,
      testCase.expected,
      testCase.name,
    );
  }
});
