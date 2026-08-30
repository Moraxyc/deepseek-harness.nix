function latestWorkflowRuns(workflowRuns) {
  const latest = new Map();

  for (const run of workflowRuns) {
    const current = latest.get(run.workflow_id);
    if (
      current === undefined ||
      run.run_number > current.run_number ||
      (run.run_number === current.run_number &&
        run.run_attempt > current.run_attempt)
    ) {
      latest.set(run.workflow_id, run);
    }
  }

  return [...latest.values()];
}

function evaluateWorkflowRuns(workflowRuns) {
  const runs = latestWorkflowRuns(workflowRuns);
  const failed = runs.find(
    (run) => run.status === "completed" && run.conclusion !== "success",
  );

  if (failed !== undefined) {
    return { state: "failure", run: failed, total: runs.length };
  }

  const pending = runs.find((run) => run.status !== "completed");
  if (pending !== undefined || runs.length === 0) {
    return { state: "pending", run: pending, total: runs.length };
  }

  return { state: "success", run: undefined, total: runs.length };
}

function describe(result) {
  if (result.state === "failure") {
    return `${result.run.name} concluded with ${result.run.conclusion}`;
  }
  if (result.state === "pending") {
    return result.run === undefined
      ? "Waiting for PR workflows"
      : `${result.run.name} is ${result.run.status}`;
  }
  return `${result.total} PR workflow${result.total === 1 ? "" : "s"} succeeded`;
}

async function updateMergeCheck({ github, context }) {
  const triggerRun = context.payload.workflow_run;
  const workflowRuns = await github.paginate(
    github.rest.actions.listWorkflowRunsForRepo,
    {
      owner: context.repo.owner,
      repo: context.repo.repo,
      head_sha: triggerRun.head_sha,
      event: "pull_request",
      per_page: 100,
    },
  );
  const result = evaluateWorkflowRuns(workflowRuns);

  await github.rest.repos.createCommitStatus({
    owner: context.repo.owner,
    repo: context.repo.repo,
    sha: triggerRun.head_sha,
    state: result.state,
    context: "Merge Check",
    description: describe(result),
    target_url: result.run?.html_url ?? triggerRun.html_url,
  });
}

module.exports = updateMergeCheck;
module.exports.evaluateWorkflowRuns = evaluateWorkflowRuns;
