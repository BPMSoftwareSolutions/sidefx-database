Put read-only exploration queries here. Run them with `npm run query -- --file sql/experiments/your-query.sql`.

Current-generation views are in `sidefx`. Full immutable observation history is in `sidefx_data`; filter its rows by `@snapshot_id` and `@projection_id` unless explicitly comparing generations. Both parameters are supplied by the query runner.

The query runner uses a dedicated SQL Server session impersonating a SELECT-only principal with `NO REVERT`, pins the current pointer for the transaction, and rolls back on completion. It emits a digest-bound receipt. Edit domain meaning only through the existing Harness lifecycle; this workspace owns no such mutation boundary.
