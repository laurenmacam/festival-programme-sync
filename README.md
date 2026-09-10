# Festival Programme Sync — Take-Home

- To stop two syncs from running at the same time, the background job grabs a short-lived lock in Redis before starting, and releases it when it's done, even if it fails. The lock has a short expiry, so it can't get stuck forever if a job crashes while holding it.

- I'd wire up real scheduling with sidekiq-cron for example OR if the upstream system had a webhook for changes, or an ?updated_since= filter, we could check for updates more frequently without having to fetch the entire programme every time.

- The filter form needs a click on "Filter" button right now. I'd make it filter live as you change a field.

- If a screening was deleted in the upstream, I would mark it as deleted with a deleted_at column. Currently I just leave it untouched.

- Every record is matched by external_id, making it safe to run the sync as many times as we want avoiding duplicateds.

- I didn't call VenueSync from ProgrammeSync because they handle data differently. VenueSync processes all venues at once, while ProgrammeSync handles one screening per transaction. I ended up duplicating the small part of the venue logic, which I'd extract into a shared place with more time.
